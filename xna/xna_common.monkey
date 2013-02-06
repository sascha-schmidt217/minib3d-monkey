Import minib3d 
Import xna  


Class XNARenderBase Extends TRender
	
	' the device
	Field _device:XNAGraphicsDevice 
	
	' states
	Field _rasterizerStates		:XNARasterizerState[]
	Field _rasterizerWire		:XNARasterizerState
	Field _rasterizerScissor	:XNARasterizerState
	Field _depthStencil			:XNADepthStencilState
	Field _depthStencilDefault	:XNADepthStencilState
	Field _depthStencilNone		:XNADepthStencilState
	Field _depthStencilNoWrite	:XNADepthStencilState
	Field _depthStencilNoDepth	:XNADepthStencilState
	Field _blendStates			:XNABlendState[] 
	Field _lastSamplerState		:XNASamplerState 	
	Field _st_uvNormal 			:UVSamplerState
	Field _st_uvSmooth			:UVSamplerState
	
	' internal resources
	Field _textureMap:= New IntMap<XNATexture> 
	Field _meshMap:= New IntMap<XNAMesh>
	Field _mesh_id, _texture_id

	' combined brushes
	Field _tex_count%,_red#,_green#,_blue#,_alpha#,_shine#,_blend%,_fx%,_tex_flags%, _textures:TTexture[]
	Field _tex_count2%,_red2#,_green2#,_blue2#,_alpha2#,_shine2#,_blend2%,_fx2%,_tex_flags2%, _textures2:TTexture[]
	
	'-----------------------------
	
	Method UpdateLight:int(cam:TCamera, light:TLight) 
	End 
	
	Method DisableLight(light:TLight) 
	End 
	
	Method Reset:Void()
	End 
	
	Method Finish:Void() 
	End 
	
	Method SetDrawShader:Void() 
	End 
	 
	Method Render:Void(ent:TEntity, cam:TCamera = Null) 
	End 
	 
	'-----------------------------
	
	Method New()
		_device = New XNAGraphicsDevice 
	End
	
	Method GraphicsInit(flags:Int)
	
		width = DeviceWidth
		height = DeviceHeight 
		
		' states
		_rasterizerStates 	= [XNARasterizerState.CullNone, XNARasterizerState.CullCounterClockwise,XNARasterizerState.CullClockwise ]
		
		_rasterizerWire = XNARasterizerState.Create()
		_rasterizerWire.CullMode = CullMode_None
		_rasterizerWire.FillMode = FillMode_WireFrame
		
		_rasterizerScissor= XNARasterizerState.Create()
		_rasterizerScissor.CullMode = CullMode_None
		_rasterizerScissor.FillMode = FillMode_Solid
		_rasterizerScissor.ScissorTestEnable = True
		
		_depthStencilDefault = XNADepthStencilState._Default
		_depthStencilNone = XNADepthStencilState.None
		
		_depthStencilNoWrite = XNADepthStencilState.Create ''may need a new state based on default
		_depthStencilNoWrite.DepthBufferEnable = True
		_depthStencilNoWrite.DepthBufferWriteEnable = False
		
		_depthStencilNoDepth	= XNADepthStencilState.Create ''is same as "none"
		_depthStencilNoDepth.DepthBufferEnable = False
		_depthStencilNoDepth.DepthBufferWriteEnable = False

		_blendStates =[XNABlendState.Premultiplied, XNABlendState.Premultiplied, XNABlendState.AlphaBlend, XNABlendState.Additive, XNABlendState.Opaque]

		Local bias:Float = 0
		_st_uvNormal = UVSamplerState.Create(TextureFilter_Point, bias)
		
		#if XNA_MIPMAP_FILTER=1 then
			_st_uvSmooth = UVSamplerState.Create(TextureFilter_Linear, bias)
		#else
			_st_uvSmooth = UVSamplerState.Create(TextureFilter_LinearMipPoint, bias)
		#End 

	End 
			
	Method UpdateVBO:Int(surf:TSurface)

		Local m:= CreateMesh(surf)
		
		If surf.reset_vbo=-1 Then surf.reset_vbo=255
			
		''update mesh positions
		If surf.reset_vbo&1
			If surf.vert_anim
				'' vertex animation
				m.SetVerticesPosition(surf.vert_anim[surf.anim_frame].buf, surf.no_verts, 2)
			Else
				m.SetVerticesPosition(surf.vert_data.buf, surf.no_verts, surf.vbo_dyn)
			Endif
		Endif

		''update rest of vertex info
		If surf.reset_vbo&2 Or surf.reset_vbo&4 Or surf.reset_vbo&8
			m.SetVertices(surf.vert_data.buf, surf.no_verts, surf.vbo_dyn)
		Endif

		If surf.reset_vbo&16
			m.SetIndices(surf.tris.buf , surf.no_tris*3, surf.vbo_dyn)
		Endif

		surf.reset_vbo=False
		
	End
	
	Method UpdateBuffers(surf:TSurface, mesh:TMesh)
		
		Local vbo:Int=True
		
		' update surf vbo if necessary
		If vbo
			
			' update vbo
			If surf.reset_vbo<>0
				UpdateVBO(surf)
			Else If surf.vbo_id[0]=0 ' no vbo - unknown reason
				surf.reset_vbo=-1
				UpdateVBO(surf)
			Endif
			
		Endif
		
		If mesh.anim
	
			' get anim_surf
			Local anim_surf2:= mesh.anim_surf[surf.surf_id] 
			
			If vbo And anim_surf2
			
				' update vbo
				If anim_surf2.reset_vbo<>0
					UpdateVBO(anim_surf2)
				Else If anim_surf2.vbo_id[0]=0 ' no vbo - unknown reason
					anim_surf2.reset_vbo=-1
					UpdateVBO(anim_surf2)
				Endif
			
			Endif
			
		Endif
	End
	
	Method FreeVBO(surf:TSurface)
		If surf.vbo_id[0]<>0 
			Local m := _meshes.Get(surf.vbo_id[0])
			m.Clear()
		Endif
	End 

	Method DeleteTexture(glid:Int[])
		If _textureMap.Contains (glid[0]) Then 
			_textureMap.Remove(glid[0])
		End 
	End
	
	Method IsPowerOfTwo?(x)
	    Return (x <> 0) And ((x & (x - 1)) = 0)
	End
	
	Method BindTexture:TTexture(tex:TTexture,flags:Int)
		
		' if mask flag is true, mask pixmap
		If flags&4
			tex.pixmap.MaskPixmap(0,0,0)
		Endif

		' pixmap -> tex

		Local width:Int =tex.pixmap.width
		Local height:Int =tex.pixmap.height
		
		If width <1 Or height <1 Then Return tex
		
		' TODO: Check max cubemap texture size
		
		If width > 2048 Or height > 2048 Then 
			Error "Exceeded Maximum texture size of 2048: " + tex.file
		End 
		
		Local mipmap:Int= 0, mip_level:Int=0
		
		If flags&8 Then mipmap=1
		
		If Not( IsPowerOfTwo(width) Or IsPowerOfTwo(height) ) Then 
			mipmap=0
			' TODO: no wrap addressing mode and no DXT compression on nonpower of two textures.
			tex.flags |= (16|32) 'clamp u,v
		End 
		
		If tex.gltex[0] = 0 Then 
			_texture_id+=1
			tex.gltex[0] = _texture_id
		End 
			
		Local t:= _device.CreateTexture(width, height, Bool(mipmap), -1 )
		
		If t Then
		
			_textureMap.Set( tex.gltex[0], t ) 
			
		End 
		
		Local pix:TPixmapXNA = TPixmapXNA(tex.pixmap)
		
		Repeat

			t.SetData(mip_level, pix.pixels, 0, pix.pixels.Length)
			
			If Not mipmap Or (width=1 And height =1) Then Exit
			If width>1 width *= 0.5
			If height>1 height *= 0.5

			If tex.resize_smooth Then 
	
				'If True'Not TEXTURE_SHARPENING_THRES
					pix=TPixmapXNA(pix.ResizePixmap(width,height) )
				'Else
				'	pix=UnsharpMask(TPixmapXNA(pix.ResizePixmap(width,height)),XNA_TEXTURE_SHARPENING_THRES)
				'End 
				
			Else 
				pix=TPixmapXNA(pix.ResizePixmapNoSmooth(width,height) )
			End
			mip_level+=1
			
		Forever
			
		tex.no_mipmaps=mip_level
	
		Return tex	
	End
		
	' combined blur + substract matrix
	Field mask:Int[] = [-1,-1,-1,
						-1,17,-1,
						-1,-1,-1]	
					
	Method Clip:Int(val%)
		If val > 255 Then 
			val = 255
		Else If val < 0 Then 
			val = 0
		End 
		Return val
	End 	
	
	Method UnsharpMask:TPixmapXNA(src:TPixmapXNA, threshold)
	
		Local width:= src.width
		Local height:= src.height
		Local dst:= TPixmapXNA(src.CreatePixmap(width,height))
		Local stride:= src.pitch*4
		
		Local srcPixels:= src.pixels
		
		For Local y = 0 Until height 
		
			For Local x = 0 Until width
			
				Local src_rgb:= src.GetPixel(x, y)
				Local src_red 	= (src_rgb & $000000ff )
				Local src_green = (src_rgb & $0000ff00 ) Shr 8
				Local src_blue 	= (src_rgb & $00ff0000 ) Shr 16
				Local src_alpha = (src_rgb & $ff000000 ) Shr 24
				Local src_mono = 0.299*src_red + 0.587*src_green + 0.114*src_blue
					
				If x < 2 Or y < 2 Or x >= width -2 Or y >= height -2

					dst.SetPixel(x,y, src_red,src_green, src_blue, src_alpha)
				
				Else
				
					Local r = 0, g = 0, b = 0
	
					For Local iy = -1 To 1
						For Local ix = -1 To 1
							Local rgb:= src.GetPixel(ix+x, iy+y)
							Local red 	= (rgb & $000000ff )
							Local green = (rgb & $0000ff00 ) Shr 8
							Local blue 	= (rgb & $00ff0000 ) Shr 16
							b += (mask[(iy + 1) * 3 + ix + 1] * blue);
		                    g += (mask[(iy + 1) * 3 + ix + 1] * green);
		                    r += (mask[(iy + 1) * 3 + ix + 1] * red);
						End 
					End 

					r = Clip(r/9)
					g = Clip(g/9)
					b = Clip(b/9)

					If Abs((0.299*r + 0.587*g + 0.114*b) - src_mono) < threshold Then 
						dst.SetPixel(x,y, src_red,src_green, src_blue, src_alpha)
					else 
						dst.SetPixel(x,y,r,g,b,src_alpha)
					End 
					
				End
			End
			
		End 
		
		Return dst
	End 
	
	
	Method CombineBrushes(brushA:TBrush,brushB:TBrush )

		' get main brush values
		_red   = brushA.red
		_green = brushA.green
		_blue  = brushA.blue
		_alpha = brushA.alpha
		_shine = brushA.shine
		_blend = brushA.blend 'entity blending, not multi-texture
		_fx    = brushA.fx

		' combine surface brush values with main brush values
		If brushB

			Local shine2#=0.0

			_red   = _red   * brushB.red
			_green = _green * brushB.green
			_blue  = _blue  * brushB.blue
			_alpha = _alpha * brushB.alpha
			shine2 = brushB.shine
			If _shine=0.0 Then _shine=shine2
			If _shine<>0.0 And shine2<>0.0 Then _shine=_shine*shine2
			If _blend=0 Then _blend=brushB.blend ' overwrite master brush if master brush blend=0
			_fx=_fx|brushB.fx

		Endif

		' get textures
		_tex_count=brushA.no_texs
		If brushB.no_texs>_tex_count Then 
			_tex_count=brushB.no_texs
		End 

		If _tex_count > 0' todo
			If brushA.tex[0]<>Null
				_textures 	= brushA.tex
			Else
				_textures	= brushB.tex	
			Endif
		Else
			_tex_flags = 0
			_textures = []
		End 
		
	End
	
	Method CompareBrushes()
	
		If _tex_count <>_tex_count2 Then Return False
		If _red<>_red2 Then Return False
		If _green<>_green2 Then Return False
		If _blue<>_blue2 Then Return False
		If _alpha<>_alpha2 Then Return False
		If _shine<>_shine2 Then Return False
		If _blend<>_blend2 Then Return False
		If _fx<>_fx2 Then Return False
		
		For Local i=0 until _tex_count
			If _textures[i]<>_textures2[i] Then Return False
		Next
	
		_red2   = _red
		_green2 = _green
		_blue2  = _blue
		_alpha2 = _alpha
		_shine2 = _shine
		_blend2 = _blend
		_fx2    = _fx
		_tex_count2 = _tex_count
				
		For local i= 0 Until _tex_count
			_textures2[i] = _textures[i]
		End 	
		
		Return True
	End 

	Method CreateMesh:XNAMesh(surf:TSurface)
	
		Local m:XNAMesh = Null
		
		If surf.vbo_id[0]=0
		
			m = _device.CreateMesh()
			
			_mesh_id+=1
			_meshMap.Set(_mesh_id,m)
			
			surf.vbo_id[0] = _mesh_id
			
		Endif
		
		If Not m Then 
			m = _meshMap.Get (surf.vbo_id[0])
		End
		
		Return m
	End 
	
End 

Class UVSamplerState

	Field _cU_cV:XNASamplerState
	Field _wU_cV:XNASamplerState
	Field _cU_wV:XNASamplerState
	Field _wU_wV:XNASamplerState
	
	Function Create:UVSamplerState(filter:Int, bias:Float)
	
		Local s:UVSamplerState = New UVSamplerState
		
		s._cU_cV = XNASamplerState.Create(filter, TextureAddressMode_Clamp, TextureAddressMode_Clamp)
		s._cU_cV.MipMapLevelOfDetailBias = bias
		
		s._wU_cV = XNASamplerState.Create(filter, TextureAddressMode_Wrap, TextureAddressMode_Clamp)
		s._wU_cV.MipMapLevelOfDetailBias = bias
		
		s._cU_wV = XNASamplerState.Create(filter, TextureAddressMode_Clamp, TextureAddressMode_Wrap)
		s._cU_wV.MipMapLevelOfDetailBias = bias
		
		s._wU_wV = XNASamplerState.Create(filter, TextureAddressMode_Wrap, TextureAddressMode_Wrap)
		s._wU_wV.MipMapLevelOfDetailBias = bias
		
		Return s
		
	End
	
End