//
//  SketchpadView.swift
//  DrawMath
//
//  Created by Lynn on 16/2/24.
//  Copyright © 2016年 Lynn. All rights reserved.
//

import Foundation
import UIKit

private let MAX_STORABLE_PATH = 5

enum Option:CustomStringConvertible {
    case BackgroundColor(UIColor)
    case StrokeColor(UIColor)
    case StrokeWidth(CGFloat)
    case LineCap(CGLineCap)
    case LineJoin(CGLineJoin)
    case ShouldAntialias(Bool)
    case AllowsAntialiasing(Bool)
    case InterpolationQuality(CGInterpolationQuality)
    
    var description: String {
        get {
            switch self {
            case .BackgroundColor(let value):
                return "\(value)"
            case .StrokeColor(let value):
                return "\(value.CGColor)"
            case .StrokeWidth(let value):
                return "\(value)"
            case .LineCap(let value):
                return "\(value)"
            case .LineJoin(let value):
                return "\(value)"
            case .ShouldAntialias(let value):
                return "\(value)"
            case .AllowsAntialiasing(let value):
                return "\(value)"
            case .InterpolationQuality(let value):
                return "\(value)"
            }
        }
    }
}

class SketchpadView:UIView {
    
    private struct ContextSet {
        var lineCap:CGLineCap
        var lineJoin:CGLineJoin
        var shouldAntialias:Bool
        var allowsAntialiasing:Bool
        var interpolationQuality:CGInterpolationQuality
        var strokeColor:CGColorRef
        var lineWidth:CGFloat
    }
    
    //显示属性
    private var contextSet:ContextSet = ContextSet(lineCap: .Round, lineJoin: .Round, shouldAntialias: true, allowsAntialiasing: true, interpolationQuality: .Default, strokeColor: UIColor.blackColor().CGColor, lineWidth: 2.0)
    
    private var persistentLayer:CGLayerRef?
    private var tempLayer:CGLayerRef?
    
    private var latestLineCache = [([CGPoint],ContextSet)]()
    //(count: MaxNumberOfStorablePath+1, repeatedValue: ([CGPoint(x: 0, y: 0)],nil))
    private var latestLineCacheTopIdx = -1
    
    private var latestPointCache = [CGPoint]()
    private var lineToPersist:([CGPoint],ContextSet)?
    
    //以后可以改成scrollview
    //internal var isDrawing:Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        latestLineCache.removeAll()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        
    }
    //绘图
    override func drawRect(rect: CGRect) {
        let ctx:CGContextRef? = UIGraphicsGetCurrentContext()
        if(persistentLayer == nil) {
            persistentLayer = CGLayerCreateWithContext(ctx, self.frame.size, nil)
        }
        if(tempLayer == nil) {
            tempLayer = CGLayerCreateWithContext(ctx, self.frame.size, nil)
        }
        //画永久存储区的线
        self.updatePersistentLayer(lineToPersist, context: ctx!)
        
        //画临时存储区的线
        self.updateTempLayer(latestLineCache, newline: latestPointCache, context: ctx!)
    }
    
    //MARK:- Public Functions
    func resetOptions(options:[Option]) {
        for option in options {
            switch option {
            case .BackgroundColor(let value):
                self.backgroundColor = value
            case .StrokeColor(let value):
                contextSet.strokeColor = value.CGColor
            case .StrokeWidth(let value):
                contextSet.lineWidth = value
            case .LineCap(let value):
                contextSet.lineCap = value
            case .LineJoin(let value):
                contextSet.lineJoin = value
            case .ShouldAntialias(let value):
                contextSet.shouldAntialias = value
            case .AllowsAntialiasing(let value):
                contextSet.allowsAntialiasing = value
            case .InterpolationQuality(let value):
                contextSet.interpolationQuality = value
            }
        }
    }
    
    /*
    可以选择图片编辑
    */
    func setupViewWithImage(image: UIImage) {
        
    }
    
    func clear() {
        persistentLayer = nil
        latestLineCache.removeAll()
        latestPointCache.removeAll()
        lineToPersist = nil
        latestLineCacheTopIdx = -1
        self.setNeedsDisplay()
    }
    
    func undo() {
        if(latestLineCache.count>0 && latestLineCacheTopIdx >= 0 && latestLineCacheTopIdx < MAX_STORABLE_PATH) {
            latestLineCacheTopIdx--
            latestPointCache.removeAll()
            self.setNeedsDisplay()
        }
    }
    
    func redo() {
        if(latestLineCache.count>0 && latestLineCacheTopIdx < latestLineCache.count-1) {
            latestLineCacheTopIdx++
            self.setNeedsDisplay()
        }
    }
    
    //MARK:- Personal Functions
    private func pasteContextSetToContext(ctxSet:ContextSet, ctx:CGContextRef) {
        CGContextSetLineCap(ctx, ctxSet.lineCap)
        CGContextSetLineJoin(ctx, ctxSet.lineJoin)
        CGContextSetShouldAntialias(ctx, true)
        CGContextSetAllowsAntialiasing(ctx, true)
        CGContextSetInterpolationQuality(ctx, .High)
        CGContextSetStrokeColorWithColor(ctx, ctxSet.strokeColor)
        CGContextSetLineWidth(ctx, ctxSet.lineWidth)
    }
    
    /*
    更新不可修复图层
    */
    private func updatePersistentLayer(line:([CGPoint],ContextSet)?, context:CGContextRef) {
        if(line != nil) {
            let pCtx = CGLayerGetContext(persistentLayer)
            
            self.pasteContextSetToContext(line!.1, ctx: pCtx!)
            
            CGContextBeginPath(pCtx)
            if(line!.0.count > 0) {
                let start = line!.0.first!
                CGContextMoveToPoint(pCtx, start.x, start.y)
                for point in line!.0 {
                    CGContextAddLineToPoint(pCtx, point.x, point.y)
                }
                
                CGContextStrokePath(pCtx)
            }
            
        }
        CGContextDrawLayerInRect(context, self.frame, persistentLayer)
    }
    
    private func updateTempLayer(oldlines:[([CGPoint],ContextSet)],newline:[CGPoint], context:CGContextRef) {
        CGContextSaveGState(context)
        
        tempLayer = nil
        if(tempLayer == nil) {
            tempLayer = CGLayerCreateWithContext(UIGraphicsGetCurrentContext(), self.frame.size, nil)
        }
        let tCtx = CGLayerGetContext(tempLayer)
        //画缓存的线
        if (latestLineCacheTopIdx >= 0) {
            for idx in 0...latestLineCacheTopIdx {
                self.pasteContextSetToContext(latestLineCache[idx].1, ctx: tCtx!)
                CGContextBeginPath(tCtx)
                if (latestLineCache[idx].0.count > 0) {
                    let start = latestLineCache[idx].0.first!
                    CGContextMoveToPoint(tCtx, start.x, start.y)
                    for point in latestLineCache[idx].0 {
                        CGContextAddLineToPoint(tCtx, point.x, point.y)
                    }
                }
                CGContextStrokePath(tCtx)
            }
        }
        
        //画当前的线
        if(newline.count > 0) {
            self.pasteContextSetToContext(contextSet, ctx: tCtx!)
            CGContextBeginPath(tCtx)
            let start = newline.first!
            CGContextMoveToPoint(tCtx, start.x, start.y)
            for point in newline {
                CGContextAddLineToPoint(tCtx, point.x, point.y)
            }
            CGContextStrokePath(tCtx)
        }
        CGContextDrawLayerInRect(context, self.frame, tempLayer)
    }
    
    //MARK:- Draw While Touch
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        lineToPersist = nil
        let startPoint = touches.first!.locationInView(self)
        latestPointCache.append(startPoint)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let movePoint = touches.first!.locationInView(self)
        latestPointCache.append(movePoint)
        self.setNeedsDisplay()
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        latestLineCacheTopIdx++
        latestLineCache.insert((latestPointCache,contextSet), atIndex: latestLineCacheTopIdx)
        latestPointCache.removeAll()
        
        if(latestLineCacheTopIdx >= MAX_STORABLE_PATH) {
            lineToPersist = latestLineCache.first!
            latestLineCache.removeFirst()
            latestLineCacheTopIdx--
        }
        self.setNeedsDisplay()
    }
}