//
//  RootViewController.swift
//  CavyLifeBand2
//
//  Created by xuemincai on 16/3/16.
//  Copyright © 2016年 xuemincai. All rights reserved.
//

import UIKit
import EZSwiftExtensions
import RealmSwift
import Log
import AddressBook
import Contacts
import KeychainAccess
import Datez
import CoreBluetooth

class RootViewController: UIViewController, CoordinateReport, PKWebRequestProtocol, PKRecordsRealmModelOperateDelegate, PKRecordsUpdateFormWeb, LifeBandBleDelegate {
    
    enum MoveDirection {
        
        case LeftMove
        case RightMove
        
        var movePoint: CGPoint {
            
            switch self {
                
            case .LeftMove:
                return CGPointMake(-(ez.screenWidth * 5 / 6), 0)
                
            case .RightMove:
                return CGPointMake(ez.screenWidth - (ez.screenWidth / 6), 0)
                
            }
            
        }
        
    }

    var homeVC: UINavigationController?
    var leftVC: LeftMenViewController?
    var bandMenuVC: RightViewController?
    let homeMaskView = UIView(frame: CGRectMake(0, 0, ez.screenWidth, ez.screenHeight))
    var realm: Realm = try! Realm()
    var updateUserInfoPara: [String: AnyObject] = [UserNetRequsetKey.UserID.rawValue: CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId]
    
    var userId: String { return CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId }
    
    var loginUserId: String { return CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId }
    
    var pkSycnCount: Int = 0 {
        
        didSet {
            
            if pkSycnCount == 3 {
                
                self.loadDataFromWeb()
                
                pkSycnCount = 0
            
            }
            
        }
        
    }
    
    deinit {
        removeNotificationObserver()
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        Log.info("\(realm.configuration.fileURL)")
        
        let bindBandKey = "CavyAppMAC_" + CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId
        
        CavyDefine.bindBandInfos.bindBandInfo.userBindBand[bindBandKey] = BindBandCtrl.bandMacAddress
        
        if BindBandCtrl.bandMacAddress.length == 6 {
            CavyDefine.bindBandInfos.bindBandInfo.defaultBindBand = LifeBandBle.shareInterface.getPeripheralName() + "," +
                String(format: "%02X:%02X:%02X:%02X:%02X:%02X",
                BindBandCtrl.bandMacAddress[0],
                BindBandCtrl.bandMacAddress[1],
                BindBandCtrl.bandMacAddress[2],
                BindBandCtrl.bandMacAddress[3],
                BindBandCtrl.bandMacAddress[4],
                BindBandCtrl.bandMacAddress[5])
        }
        
        Log.info("defaultBindBand = \(CavyDefine.bindBandInfos.bindBandInfo.defaultBindBand)")
        
        loadHomeView()
            
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RootViewController.onClickMenu), name: NotificationName.HomeLeftOnClickMenu.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RootViewController.onClickBandMenu), name: NotificationName.HomeRightOnClickMenu.rawValue, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RootViewController.showHomeView), name: NotificationName.HomeShowHomeView.rawValue, object: nil)
        
        LifeBandBle.shareInterface.lifeBandBleDelegate = self
        
        // 需要等待 LifeBandBle.shareInterface 初始化，这里延时1s连接
        NSTimer.runThisAfterDelay(seconds: 1) {
            
            LifeBandBle.shareInterface.bleConnect(BindBandCtrl.bandMacAddress) {
                
                LifeBandCtrl.shareInterface.setDateToBand(NSDate())
                
                let lifeBandModel = (LifeBandModelType.LLA.rawValue | LifeBandModelType.Step.rawValue | LifeBandModelType.Tilt.rawValue)
                LifeBandCtrl.shareInterface.getLifeBandInfo {
                    
                    // 如果不等于生活手环模式，则重新设置生活手环模式
                    if $0.model & lifeBandModel  != lifeBandModel {
                        LifeBandCtrl.shareInterface.seLifeBandModel()
                    }
                    
                    BindBandCtrl.fwVersion = $0.fwVersion
                    
                }
                
                LifeBandCtrl.shareInterface.installButtonEven()
                self.syncDataFormBand()
            }
        }
        
        addNotificationObserver(LifeBandCtrlNotificationName.BandButtonEvenClick4.rawValue, selector: #selector(RootViewController.callEmergency))
        
    }
    
    /**
     向紧急联系人发消息
     
     - author: sim cai
     - date: 2016-05-31
     */
    func callEmergency() {
        
        do { try EmergencyWebApi.shareApi.sendEmergencyMsg() }
        catch let error
        { Log.error("Cell EmergencyWebApi.shareApi.sendEmergencyMsg error (\(error))") }
        
    }
    
    
    /**
     加载主页面视图
     */
    func loadHomeView() {
        
        leftVC = StoryboardScene.Home.instantiateLeftView()
        homeVC = UINavigationController(rootViewController: StoryboardScene.Home.instantiateHomeView())
        bandMenuVC = StoryboardScene.Home.instantiateRightView()
        
        self.view.addSubview(leftVC!.view)
        self.view.addSubview(bandMenuVC!.view)
        self.view.addSubview(homeVC!.view)
        
        bandMenuVC!.view.snp_makeConstraints {
            $0.top.bottom.right.equalTo(self.view)
            $0.left.equalTo(self.view).offset(ez.screenWidth / 6)
        }
        
        syncUserInfo()
        
        syncPKRecords()
        
    }
    
    /**
     上报坐标
     
     - parameter isLocalShare:
     */
    func userCoordinateReport(isLocalShare: Bool) {
        
        guard isLocalShare else {
            return
        }
        
        self.coordinateReportServer()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /**
     从服务器将数据更新到本地
     */
    func syncUserInfo() {
        
        guard let userInfo: UserInfoModel = queryUserInfo(CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId) else {
        
            querySyncDate()
            return
        }
        
        userCoordinateReport(userInfo.isLocalShare)
        
        updateSyncDate(userInfo)
        
        CavyDefine.userNickname = userInfo.nickname
        CavyDefine.loginUserBaseInfo.loginUserInfo.loginAvatar = userInfo.avatarUrl
        
    }
    
    /**
     将本地数据同步到服务器
     
     - parameter userInfo: 用户信息
     */
    func updateSyncDate(userInfo: UserInfoModel) {
        
        if userInfo.isSync == true {
            return
        }
        
        updateUserInfoPara += [UserNetRequsetKey.UserID.rawValue: userInfo.userId,
                               UserNetRequsetKey.Sex.rawValue: userInfo.sex.toString,
                               UserNetRequsetKey.Height.rawValue: userInfo.height,
                               UserNetRequsetKey.Weight.rawValue: userInfo.weight,
                               UserNetRequsetKey.Birthday.rawValue: userInfo.birthday,
                               UserNetRequsetKey.Address.rawValue: userInfo.address,
                               UserNetRequsetKey.StepNum.rawValue: userInfo.stepNum,
                               UserNetRequsetKey.SleepTime.rawValue: userInfo.sleepTime,
                               UserNetRequsetKey.IsNotification.rawValue: userInfo.isNotification,
                               UserNetRequsetKey.IsLocalShare.rawValue: userInfo.isLocalShare,
                               UserNetRequsetKey.IsOpenBirthday.rawValue: userInfo.isOpenBirthday,
                               UserNetRequsetKey.IsOpenHeight.rawValue: userInfo.isOpenHeight,
                               UserNetRequsetKey.IsOpenWeight.rawValue: userInfo.isOpenWeight]
        
        self.setUserInfo {
            
            guard $0 else {
                return
            }
            
            self.updateUserInfo(CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId) {
                $0.isSync = true
                return $0
            }
            
        }
        
    }
    
    /**
     将服务器的用户信息同步到本地
     */
    func querySyncDate() {
        
        queryUserInfoByNet{ resultUserInfo in
            
            guard let userInfo = resultUserInfo else {
                return
            }
            
            CavyDefine.userNickname = userInfo.nickName ?? ""
            
            let userInfoModel = UserInfoModel(userId: CavyDefine.loginUserBaseInfo.loginUserInfo.loginUserId, userProfile: userInfo)
            
            self.userCoordinateReport(userInfoModel.isLocalShare)
            
            self.addUserInfo(userInfoModel)
            
        }
        
    }
    
    /**
     将数据库未同步的pk记录同步到服务器
     */
    func syncPKRecords() {
        
        //删除pk
        if let finishList: [PKFinishRealmModel] = self.getUnSyncPKList(PKFinishRealmModel.self) {
            self.deletePKFinish(finishList, loginUserId: self.loginUserId, callBack: {
                
                for finish in finishList {
                    self.syncPKRecordsRealm(PKFinishRealmModel.self, pkId: finish.pkId)
                }
                
                self.pkSycnCount += 1
                
            }, failure: {(errorMsg) in
                Log.warning(errorMsg)
            })
        } else {
            self.pkSycnCount += 1
        }
        
        //接受pk
        if let acceptList: [PKDueRealmModel] = self.getUnSyncPKList(PKDueRealmModel.self) {
            
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFromString("yyyy-MM-dd HH:mm:ss")
            
            self.acceptPKInvitation(acceptList, loginUserId: self.loginUserId, callBack: {
                for accept in acceptList {
                    
                    self.changeDueBeginTime(accept, time: dateFormatter.stringFromDate(NSDate()))
                    self.syncPKRecordsRealm(PKDueRealmModel.self, pkId: accept.pkId)
                }
                
                self.pkSycnCount += 1
            }, failure: {(errorMsg) in
                Log.warning(errorMsg)
            })
        } else {
            self.pkSycnCount += 1
        }
        
        //撤销pk
        if let undoList: [PKWaitRealmModel] = self.getUnSyncWaitPKListWithType(.UndoWait) {
            self.undoPK(undoList, loginUserId: self.loginUserId, callBack: {
                for undo in undoList {
                    self.syncPKRecordsRealm(PKWaitRealmModel.self, pkId: undo.pkId)
                }
                
                self.pkSycnCount += 1
            }, failure: {(errorMsg) in
                Log.warning(errorMsg)
            })
        } else {
            self.pkSycnCount += 1
        }

    }

    /**
     点击菜单按钮
     */
    func onClickMenu() {

        showLeftView()

    }

    /**
     显示左侧列表视图
     */
    func showLeftView() {

        hiddenHomeView(.RightMove)

    }
    
    /**
     显示手环设置菜单
     */
    func onClickBandMenu() {
        
        hiddenHomeView(.LeftMove)
        
    }
    
    /**
     隐藏主页
     
     - parameter direction: 主页移动的方向
     */
    func hiddenHomeView(direction: MoveDirection) {
        
        homeMaskView.backgroundColor = UIColor.clearColor()
        
        if direction == .LeftMove {
            bandMenuVC?.view.hidden = false
            leftVC?.view.hidden = true
        } else {
            bandMenuVC?.view.hidden = true
            leftVC?.view.hidden = false
        }
        
        homeMaskView.addTapGesture { [unowned self] _ in
            
            self.showHomeView()
            
        }
        
        homeVC!.view.addSubview(homeMaskView)
        
        UIView.animateWithDuration(0.5) { [unowned self] _ in
            
            self.homeVC!.view.frame.origin = direction.movePoint
            self.homeMaskView.backgroundColor = UIColor(named: .HomeViewMaskColor)
            
        }
        
    }

    /**
     隐藏左侧菜单
     */
    func showHomeView() {
        
        UIView.animateWithDuration(0.5, animations: { [unowned self] in
            
            self.homeVC!.view.frame.origin = CGPointMake(0, 0)
            self.homeMaskView.backgroundColor = UIColor.clearColor()
        
        }) { [unowned self] in
                
            if $0 == true {
                
                self.homeMaskView.removeFromSuperview()
                    
            }
        }

    }
    
    func bleMangerState(bleState: CBCentralManagerState) {
        
        if bleState == .PoweredOn &&
            (LifeBandBle.shareInterface.getConnectState() == .Connected || LifeBandBle.shareInterface.getConnectState() == .Connecting) {
            LifeBandBle.shareInterface.startScaning()
        }
        
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension RootViewController: QueryUserInfoRequestsDelegate, UserInfoRealmOperateDelegate, SetUserInfoRequestsDelegate {
    
    var userInfoPara: [String: AnyObject] {
        get {
            return updateUserInfoPara
        }
        
        set { }
    }
    
}

extension UserInfoModel {
    
    convenience init(userId: String, userProfile: UserProfile) {
        
        self.init()
        
        self.userId         = userId
        self.nickname       = userProfile.nickName
        self.sex            = userProfile.sex.toInt() ?? 0
        self.address        = userProfile.address
        self.avatarUrl      = userProfile.avatarUrl
        self.birthday       = userProfile.birthday
        self.height         = userProfile.height
        self.weight         = userProfile.weight
        self.sleepTime      = userProfile.sleepTime
        self.stepNum        = userProfile.stepNum

        self.isLocalShare   = userProfile.isLocalShare
        self.isNotification = userProfile.isNotification
        self.isOpenHeight   = userProfile.isOpenHeight
        self.isOpenWeight   = userProfile.isOpenWeight
        self.isOpenBirthday = userProfile.isOpenBirthday
        self.isSync         = true

    }
    
}
