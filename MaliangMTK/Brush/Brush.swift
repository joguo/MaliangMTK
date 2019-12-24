//
//  Brush.swift
//  MaLiang
//
//  Created by Harley.xk on 2017/11/6.
//

import Foundation
import MetalKit
import Cocoa


open class Brush {
    
    // unique identifier for a specifyed brush, should not be changed over all your apps
    // make this value uniform when saving or reading canvas content from a file
    open var name: String
    
    /// interal texture
    open private(set) var textureID: String?
    
    /// target to draw
    open private(set) weak var target: Canvas?

    // opacity of texture, affects the darkness of stroke
    open var opacity: CGFloat = 0.3 {
        didSet {
            updateRenderingColor()
        }
    }
    
    // width of stroke line in points
    open var pointSize: CGFloat = 4

    // this property defines the minimum distance (measureed in points) of nearest two textures
    // defaults to 1, this means erery texture calculated will be rendered, dictance calculation will be skiped
    open var pointStep: CGFloat = 1
    
    // sensitive of pointsize changed from force, if sets to 0, stroke size will not be affected by force
    // sets to 1 to make an everage affect
    open var forceSensitive: CGFloat = 0
    
    // indicate if the stroke size in visual will be scaled along with the Canvas
    // defaults to false, the stroke size in visual will stay with the original value
    open var scaleWithCanvas = false
    
    // force used when tap the canvas, defaults to 0.1
    open var forceOnTap: CGFloat = 1
    
    /// color of stroke
    open var color: NSColor = .black {
        didSet {
            updateRenderingColor()
        }
    }
    
    /// texture rotation for this brush
    public enum Rotation {
        /// angele is fixed to specified value
        case fixed(CGFloat)
        /// angle of texture is random
        case random
        /// angle of texture is ahead with to line orientation
        case ahead
    }
    
    /// texture rotation for this brush, defaults to .fixed(0)
    open var rotation = Rotation.fixed(0)
    
    // randering color, same color to the color property with alpha reseted to alpha * opacity
    internal var renderingColor: MLColor = MLColor(red: 0, green: 0, blue: 0, alpha: 1)
    
    // called when color or opacity changed
    private func updateRenderingColor() {
        renderingColor = color.toMLColor(opacity: opacity)
    }
    
    // designed initializer, will be called by target when reigster called
    // identifier is not necessary if you won't save the content of your canvas to file
    required public init(name: String?, textureID: String?, target: Canvas) {
        self.name = name ?? UUID().uuidString
        self.target = target
        self.textureID = textureID
        if let id = textureID {
            texture = target.findTexture(by: id)?.texture
        }
        updatePointPipeline()
    }
    
    /// use this brush to draw
    open func use() {
        target?.currentBrush = self
    }
    
    
    private var canvasScale: CGFloat {
        return target?.screenTarget?.scale ?? 1
    }
    
    private var canvasOffset: CGPoint {
        return target?.screenTarget?.contentOffset ?? .zero
    }
    
    // MARK: - Render tools
    /// texture for this brush, readonly
    open private(set) weak var texture: MTLTexture?
    
    /// pipeline state for this brush
    open private(set) var pipelineState: MTLRenderPipelineState!
    
    /// make shader library for this brush, overrides to provide your own shader library
    open func makeShaderLibrary(from device: MTLDevice) -> MTLLibrary? {
        return device.libraryForMaLiang()
    }
    
    /// make shader vertex function from the library made by makeShaderLibrary()
    /// overrides to provide your own vertex function
    open func makeShaderVertexFunction(from library: MTLLibrary) -> MTLFunction? {
        return library.makeFunction(name: "vertex_point_func")
    }
    
    /// make shader fragment function from the library made by makeShaderLibrary()
    /// overrides to provide your own fragment function
    open func makeShaderFragmentFunction(from library: MTLLibrary) -> MTLFunction? {
        if texture == nil {
            return library.makeFunction(name: "fragment_point_func_without_texture")
        }
        return library.makeFunction(name: "fragment_point_func")
    }
    
    /// Blending options for this brush, overrides to implement your own blending options
    open func setupBlendOptions(for attachment: MTLRenderPipelineColorAttachmentDescriptor) {
        attachment.isBlendingEnabled = true

        attachment.rgbBlendOperation = .add
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        attachment.alphaBlendOperation = .add
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }
    
    // MARK: - Render Actions

    private func updatePointPipeline() {
        
        guard let target = target, let device = target.device, let library = makeShaderLibrary(from: device) else {
            return
        }
        
        let rpd = MTLRenderPipelineDescriptor()
        
        if let vertex_func = makeShaderVertexFunction(from: library) {
            rpd.vertexFunction = vertex_func
        }
        if let fragment_func = makeShaderFragmentFunction(from: library) {
            rpd.fragmentFunction = fragment_func
        }
        
        rpd.colorAttachments[0].pixelFormat = target.colorPixelFormat
        setupBlendOptions(for: rpd.colorAttachments[0]!)
        pipelineState = try! device.makeRenderPipelineState(descriptor: rpd)
    }

}
