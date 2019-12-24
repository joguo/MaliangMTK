//
//  CanvasData.swift
//  MaLiang
//
//  Created by Harley-xk on 2019/4/22.
//

import Foundation

/// base element that can be draw on canvas
public protocol CanvasElement: Codable {
    
    /// index in the emelent list of canvas
    /// element with smaller index will draw earlier
    /// Automatically set by Canvas.Data
    var index: Int { get set }
    
    /// draw this element on specifyied target
    func drawSelf(on target: RenderTarget?)
}

/// clear action, a command to clear the canvas
public struct ClearAction: CanvasElement {
    public var index: Int = 0
    public func drawSelf(on target: RenderTarget?) {
        target?.clear()
    }
}

/// content data on canvas
open class CanvasData {
    
    /// elements array before an clear action, avoid to change this value when drawing
    open var clearedElements: [[CanvasElement]] = []
    
    /// current drawing elements, avoid to change this value when drawing
    open var elements: [CanvasElement] = []
    
    /// current unfinished element, avoid to change this value when drawing
    open var currentElement: CanvasElement?
    
    
    /// add a chartlet to elements
    open func append(chartlet: Chartlet) {
        finishCurrentElement()
        chartlet.index = lastElementIndex + 1
        elements.append(chartlet)
        
        observers.element(chartlet, didFinishOn: self)
        h_onElementFinish?(self)
    }
    
    /// index for latest element
    open var lastElementIndex: Int {
        return elements.last?.index ?? 0
    }
    
    open func finishCurrentElement() {
        guard var element = currentElement else {
            return
        }
        element.index = lastElementIndex + 1
        elements.append(element)
        currentElement = nil
        
        observers.element(element, didFinishOn: self)
        h_onElementFinish?(self)
    }
    
    open func appendClearAction() {
        finishCurrentElement()
        
        guard elements.count > 0 else {
            return
        }
        clearedElements.append(elements)
        elements.removeAll()
        
        observers.dataDidClear(self)
    }
    
    
    // MARK: - Observers
    internal var observers = DataObserverPool()
    
    // add an observer to observe data changes, observers are not retained
    open func addObserver(_ observer: DataObserver) {
        // pure nil objects
        observers.clean()
        observers.addObserver(observer)
    }
    
    // MARK: - EventHandler
    public typealias EventHandler = (CanvasData) -> ()
    
    private var h_onElementBegin: EventHandler?
    private var h_onElementFinish: EventHandler?
    private var h_onRedo: EventHandler?
    private var h_onUndo: EventHandler?
    
    @available(*, deprecated, message: "Use Observers instead")
    @discardableResult
    public func onElementBegin(_ h: @escaping EventHandler) -> Self {
        h_onElementBegin = h
        return self
    }
    
    @available(*, deprecated, message: "Use Observers instead")
    @discardableResult
    public func onElementFinish(_ h: @escaping EventHandler) -> Self {
        h_onElementFinish = h
        return self
    }
    
    @available(*, deprecated, message: "Use Observers instead")
    @discardableResult
    public func onRedo(_ h: @escaping EventHandler) -> Self {
        h_onRedo = h
        return self
    }
    
    @available(*, deprecated, message: "Use Observers instead")
    @discardableResult
    public func onUndo(_ h: @escaping EventHandler) -> Self {
        h_onUndo = h
        return self
    }
}
