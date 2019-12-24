//
//  Canvas.swift
//  MaLiang
//
//  Created by Harley.xk on 2018/4/11.
//

import Cocoa

open class Canvas: MetalView {
    
    // MARK: - Brushes
    
    /// default round point brush, will not show in registeredBrushes
    open var defaultBrush: Brush!
    
    /// printer to print image textures on canvas
    open private(set) var printer: Printer!
    
    /// the actural size of canvas in points, may larger than current bounds
    /// size must between bounds size and 5120x5120
    open var size: CGSize {
        return drawableSize
    }
    
    // delegate & observers
    
    open weak var renderingDelegate: RenderingDelegate?
    
    internal var actionObservers = ActionObserverPool()
    
    // add an observer to observe data changes, observers are not retained
    open func addObserver(_ observer: ActionObserver) {
        // pure nil objects
        actionObservers.clean()
        actionObservers.addObserver(observer)
    }
    
    /// Register a brush with image data
    ///
    /// - Parameter texture: texture data of brush
    /// - Returns: registered brush
    @discardableResult open func registerBrush<T: Brush>(name: String? = nil, from data: Data) throws -> T {
        let texture = try makeTexture(with: data)
        let brush = T(name: name, textureID: texture.id, target: self)
        registeredBrushes.append(brush)
        return brush
    }
    
    /// Register a brush with image data
    ///
    /// - Parameter file: texture file of brush
    /// - Returns: registered brush
    @discardableResult open func registerBrush<T: Brush>(name: String? = nil, from file: URL) throws -> T {
        let data = try Data(contentsOf: file)
        return try registerBrush(name: name, from: data)
    }
    
    /// Register a new brush with texture already registered on this canvas
    ///
    /// - Parameter textureID: id of a texture, default round texture will be used if sets to nil or texture id not found
    open func registerBrush<T: Brush>(name: String? = nil, textureID: String? = nil) throws -> T {
        let brush = T(name: name, textureID: textureID, target: self)
        registeredBrushes.append(brush)
        return brush
    }
    
    /// current brush used to draw
    /// only registered brushed can be set to current
    /// get a brush from registeredBrushes and call it's use() method to make it current
    open internal(set) var currentBrush: Brush!
    
    /// All registered brushes
    open private(set) var registeredBrushes: [Brush] = []
    
    /// find a brush by name
    /// nill will be retured if brush of name provided not exists
    open func findBrushBy(name: String?) -> Brush? {
        return registeredBrushes.first { $0.name == name }
    }
    
    /// All textures created by this canvas
    open private(set) var textures: [MLTexture] = []
    
    /// make texture and cache it with ID
    ///
    /// - Parameters:
    ///   - data: image data of texture
    ///   - id: id of texture, will be generated if not provided
    /// - Returns: created texture, if the id provided is already exists, the existing texture will be returend
    @discardableResult
    override open func makeTexture(with data: Data, id: String? = nil) throws -> MLTexture {
        // if id is set, make sure this id is not already exists
        if let id = id, let exists = findTexture(by: id) {
            return exists
        }
        let texture = try super.makeTexture(with: data, id: id)
        textures.append(texture)
        return texture
    }
    
    @discardableResult
    override func makeTexture(with cgImage: CGImage, id: String? = nil) throws -> MLTexture {
        // if id is set, make sure this id is not already exists
        if let id = id, let exists = findTexture(by: id) {
            return exists
        }
        
        let texture = try super.makeTexture(with: cgImage, id: id)
        textures.append(texture)
        return texture
    }
    
    @discardableResult
    func flushTexture(with cgImage: CGImage, id: String? = nil) throws -> MLTexture {
        textures.removeAll { $0.id == id }
        return try makeTexture(with: cgImage, id: id)
    }
    
//    @discardableResult
//    override func makeTexture(with pixelBuffer: CVPixelBuffer, id: String? = nil) throws -> MLTexture {
//        textures.removeAll { $0.id == id }
//
//        let texture = try super.makeTexture(with: pixelBuffer, id: id)
//        textures.append(texture)
//        return texture
//    }
    
    /// find texture by textureID
    open func findTexture(by id: String) -> MLTexture? {
        return textures.first { $0.id == id }
    }
    
    // MARK: - Zoom and scale
    /// the scale level of view, all things scales
    open var scale: CGFloat {
        get {
            return screenTarget?.scale ?? 1
        }
        set {
            screenTarget?.scale = newValue
        }
    }
    
    /// the zoom level of render target, only scale render target
    open var zoom: CGFloat {
        get {
            return screenTarget?.zoom ?? 1
        }
        set {
            screenTarget?.zoom = newValue
        }
    }
    
    /// the offset of render target with zoomed size
    open var contentOffset: CGPoint {
        get {
            return screenTarget?.contentOffset ?? .zero
        }
        set {
            screenTarget?.contentOffset = newValue
        }
    }
    
    /// this will setup the canvas and gestures、default brushs
    open override func setup() {
        super.setup()
        
        /// initialize default brush
        defaultBrush = Brush(name: "maliang.default", textureID: nil, target: self)
        currentBrush = defaultBrush
        
        /// initialize printer
        printer = Printer(name: "maliang.printer", textureID: nil, target: self)
        
        data = CanvasData()
    }
//
//    /// take a snapshot on current canvas and export an image
//    open func snapshot() -> UIImage? {
//        UIGraphicsBeginImageContextWithOptions(bounds.size, false, contentScaleFactor)
//        drawHierarchy(in: bounds, afterScreenUpdates: true)
//        let image = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        return image
//    }
//
    /// clear all things on the canvas
    ///
    /// - Parameter display: redraw the canvas if this sets to true
    open override func clear(display: Bool = true) {
        super.clear(display: display)
        
        if display {
            data.appendClearAction()
        }
    }
    
    open override func layout() {
        super.layout()
        redraw()
    }
    
    // MARK: - Document
    public private(set) var data: CanvasData!
    
    /// reset data on canvas, this method will drop the old data object and create a new one.
    /// - Attention: SAVE your data before call this method!
    /// - Parameter redraw: if should redraw the canvas after, defaults to true
    open func resetData(redraw: Bool = true) {
        let oldData = data!
        let newData = CanvasData()
        // link registered observers to new data
        newData.observers = data.observers
        data = newData
        if redraw {
            self.redraw()
        }
        data.observers.data(oldData, didResetTo: newData)
    }
    
    
    /// redraw elemets in document
    /// - Attention: thie method must be called on main thread
    open func redraw(on target: RenderTarget? = nil) {
        
        guard let target = target ?? screenTarget else {
            return
        }
        
        data.finishCurrentElement()
        
        target.updateBuffer(with: drawableSize)
        target.clear()
        
        data.elements.forEach { $0.drawSelf(on: target) }
        
        /// submit commands
        target.commitCommands()
        
        actionObservers.canvas(self, didRedrawOn: target)
    }

    
    // MARK: - Rendering
    
    /// draw a chartlet to canvas
    ///
    /// - Parameters:
    ///   - point: location where to draw the chartlet
    ///   - size: size of texture
    ///   - textureID: id of texture for drawing
    ///   - rotation: rotation angle of texture for drawing
    open func renderChartlet(at point: CGPoint, size: CGSize, textureID: String, rotation: CGFloat = 0, shownRect: NSRect = NSRect(x: 0, y: 0, width: 1, height: 1)) {
        
        let chartlet = Chartlet(center: point, size: size, textureID: textureID, angle: rotation, canvas: self, shownRect: shownRect)
        
        guard renderingDelegate?.canvas(self, shouldRenderChartlet: chartlet) ?? true else {
            return
        }
        
        data.append(chartlet: chartlet)
        chartlet.drawSelf(on: screenTarget)
        screenTarget?.commitCommands()
        setNeedsDisplay(frame)
        
        actionObservers.canvas(self, didRenderChartlet: chartlet)
    }
    
}
