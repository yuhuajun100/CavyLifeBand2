//
//  HomeDataCellFlowLayout.swift
//  CavyLifeBand2
//
//  Created by Jessica on 16/4/14.
//  Copyright © 2016年 xuemincai. All rights reserved.
//

import UIKit
import EZSwiftExtensions

class HomeDataCellFlowLayout: UICollectionViewFlowLayout {

    override func prepareLayout() {
        
        self.itemSize = CGSizeMake(ez.screenWidth / 3, 50)
        self.scrollDirection = UICollectionViewScrollDirection.Horizontal
        
        self.minimumLineSpacing = 0
        
        // 设置边距(让第一张图片与最后一张图片出现在最中央)
        let inset = ez.screenWidth  * 0.5 - self.itemSize.width * 0.5
        self.sectionInset = UIEdgeInsetsMake(0, inset, 0, inset)
                
    }
    
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        let array: Array<UICollectionViewLayoutAttributes> = super.layoutAttributesForElementsInRect(rect)!
                
        let centerX = ez.screenWidth * 0.5 + self.collectionView!.contentOffset.x
        for attrs in array {
            let itemCenterX = attrs.center.x

            let scale = 1 - 0.5 * fabs(itemCenterX - centerX) / 200

            attrs.transform3D = CATransform3DMakeScale(scale, scale, 1)
 
        }
        
        
        return array
    }
    
 
    
}