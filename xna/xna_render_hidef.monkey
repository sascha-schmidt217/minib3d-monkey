
Import minib3d
Import minib3d.xna.xna_common

Class XNARender Extends XNARenderBase

Private 

	'' default shader interfaces
	Field _shaderFog:IShaderFog
	Field _shaderColor:IShaderColor
	Field _shaderTexture:IShaderTexture
	Field _shaderLights:IShaderLights
	Field _shaderMatrices:IShaderMatrices

	Field _lightEnabled?, _depthBufferEnabled?, _fogEnabled?, _disableDepth?, _lightIsEnabled?
	Field _ambient_red, _ambient_green, _ambient_blue 

	'' util
	Field _lights:= New List<TLight>' lights per frame/camera
	Field _initializedShader:= New IntMap<TShader>
	Field _shader:XNAShader 'currently selected shader
	Field _lastSurf:TSurface ''used to batch sprite state switching
	Field _lastTexture:TTexture
	Field _cam:TCamera
	Field _alpha_list:= New List<TSurface>
	
Public 

	Method GraphicsInit(flags:Int)
		Super.GraphicsInit(flags)
		
		''need to set tpixmap class
		TPixmapXNA.Init()
		
		Reset()
		
		XNAShader.Device = _device
		
		' load default shader
		TShader.LoadDefaultShader(New XNADefaultShader)	
		
	End
	
	Method Reset:Void()
		
		''clear mojo state
		EndMojoRender()
		
		TRender.alpha_pass = 0
		
		 _device.SamplerState(0, _st_uvNormal._cU_cV )
		_lastSamplerState = _st_uvNormal._cU_cV
		_device.BlendState = _blendStates[0]
		_device.RasterizerState = XNARasterizerState.CullClockwise;
        _device.DepthStencilState = XNADepthStencilState.None;
        
        ' clear lights
		_lights.Clear()
		
		'' force per camera constants update
		_initializedShader.Clear()
		UpdateShader(Null)
		TShader.DefaultShader()
	End 
	
	Method Finish:Void() 
	End 
	
	Method SetDrawShader:Void()
		
		' default shader selects automatically accordant permutation

	End

	Method Render:Void(ent:TEntity, cam:TCamera = Null) 	

		Local mesh:TMesh = TMesh(ent)
		If Not mesh Then Return
		Local shader:= XNAShader(TShader.g_shader)
		Local shaderSwitch? = False
		
		'' - not target specific
		If XNAShader(ent.shader_brush) And (Not shader.override) And ent.shader_brush.active

			shader = XNAShader(ent.shader_brush)

			'' if we are using a brush with a dedicated render routine
			If IShaderEntity(shader)'' call entity render routine
				IShaderEntity(shader).RenderEntity(cam, ent)
				Return
			Else
				'' assign brush shader
				shaderSwitch = UpdateShader(shader)
			End
			
		Else 
			
			'' assign global shader
			shaderSwitch = UpdateShader(shader)
			
		End
		
		'' update per object constants
		If _shaderMatrices Then 
		
			If TSprite(ent) Then 
				_shaderMatrices.WorldMatrix(TSprite(ent).mat_sp)
			Else
				_shaderMatrices.WorldMatrix(ent.mat)
			End 
			

			_shaderMatrices.EyePosition( _cam.mat.grid[3][0],
										 _cam.mat.grid[3][1],
										 _cam.mat.grid[3][2]) 

		End
	
		''--------------------------
		
		'' draw surfaces with alpha last
		Local temp_list:List<TSurface> = mesh.surf_list
		_alpha_list.Clear()
		
		''run through surfaces twice, sort alpha surfaces for second pass
		For Local alphaloop:= alpha_pass To 1 ''if alpha_pass is on, no need to reorder alpha surfs
			For Local surf:=  Eachin temp_list

				''draw alpha surfaces last in second loop
				''also catch surfaces with no vertex
				If surf.no_verts=0 Then Continue
				If (surf.alpha_enable And alphaloop < 1)
					_alpha_list.AddLast(surf)				
					Continue
				Endif

				' Update vertex & index buffers
				UpdateBuffers(surf, mesh)

				Local skip_sprite_state? = False
				
				' skip per material constants update if nothing changed
				CombineBrushes(ent.brush, surf.brush)
				If Not CompareBrushes() Then 

					''batch optimizations (sprites/meshes)
					If _lastSurf = surf And Not shaderSwitch
						skip_sprite_state = True
					Else
						_lastSurf = surf
					Endif

					If Not skip_sprite_state Then 
					
						SetStates(ent, surf)
						SetPerObjConstants()

					End 
					
					SetTextures(surf, ent, skip_sprite_state)
					
				End 

				shader.Update()
				shader.Apply()

				Local xnaMesh:XNAMesh
				If mesh.anim
					xnaMesh = _meshMap.Get(mesh.anim_surf[surf.surf_id].vbo_id[0])
				Else
					xnaMesh = _meshMap.Get(surf.vbo_id[0])
				End

				If Not xnaMesh Then surf.vbo_id[0]=0; Continue
				
				' render
				xnaMesh.Bind()
				xnaMesh.Render()				
				
			End 
		End 
	End 

	Method UpdateCamera(cam:TCamera) 

		' set the viewport
		_device.Viewport(cam.vx,cam.vy,cam.vwidth,cam.vheight)
	
		' clear buffers
		_device.ClearScreen(cam.cls_r,cam.cls_g,cam.cls_b, cam.cls_color, cam.cls_zbuffer, False )
	
		'' store settings 		
		_cam = cam
		
		If cam.draw2D
			_fogEnabled = False
			_lightEnabled = False
			If _shaderColor Then 
				_shaderColor.AmbientColor(1,1,1)
			End 
		Else
			_fogEnabled = cam.fog_mode>0
			_lightEnabled = true
		End
		
	End 
	
	Method UpdateLight(cam:TCamera, light:TLight) 
		_lights.AddLast(light)
	End 
	
	Method DisableLight(light:TLight) '' is this used somewhere??
		Error "D3D11Render -> DisableLight not implemented..."
	End
	
	Method CreateShader:TShader(vs_file$, ps_file$)
		Return New D3D11Shader(_deviceContext, vs_file, ps_file )
	End 

Private 

	''
	'' internal
	''
	
	Method IsPowerOfTwo?(x)
	    Return (x <> 0) And ((x & (x - 1)) = 0)
	End
	
	Method SetStates(ent:TEntity, surf:TSurface)
	
		' fx flag 16 - disable backface culling
		If _fx&16 Then 
			_device.RasterizerState = _rasterizerStates[0] 
		Else 
			_device.RasterizerState = _rasterizerStates[2]
		End 
		
		''global wireframe rendering
		If TRender.render.wireframe
			_device.RasterizerState = _rasterizerWire
		Endif

		' take into account auto fade alpha
		_alpha=_alpha-ent.fade_alpha
		
		' if surface contains alpha info, enable blending
		''and  fx flag 64 - disable depth testing
		
		If _fx&64 Or _cam.draw2D
			_device.DepthStencilState = _depthStencilNoDepth
			
		Elseif (ent.alpha_order<>0.0 Or surf.alpha_enable=True)
			_device.DepthStencilState = _depthStencilNoWrite
			
		Else
			_device.DepthStencilState = _depthStencilDefault
		Endif	
		
		' blend mode
		_device.BlendState = _blendStates[_blend]
					
	End 
	
	Method SetPerObjConstants()
		
		'' shader lighting interface
		If _shaderLights Then 
			If Not _lightEnabled Or _fx&1 Then 
				_shaderLights.LightingEnabled(False)
				_lightIsEnabled = False
			Else
				_shaderLights.LightingEnabled(True)
				_lightIsEnabled = true
			End 
		End 
				
		'' shader color interface
		If _shaderColor Then 
		
			' fx flag 2 - vertexcolor 
			If _fx&2
				_shaderColor.VertexColorEnabled(True)
			Else
				_shaderColor.VertexColorEnabled(False)
			Endif

			_shaderColor.DiffuseColor(_red, _green, _blue, _alpha)
			
			' fx flag 1 - full bright 
			If Not _cam.draw2D Then 
				If _fx&1 
					_shaderColor.AmbientColor(1,1,1)
				Else
					_shaderColor.AmbientColor(TLight.ambient_red ,TLight.ambient_green,TLight.ambient_blue )
				Endif
			Endif
			
			_shaderColor.Shine(_shine)
			
		End 
		
		'' shader fog interface
		If _shaderFog Then 
		
			' fx flag 8 - disable fog
			If  Not _fogEnabled Or (_cam.fog_mode And _fx&8)
				_shaderFog.FogEnabled(False)
			Else If _cam.fog_mode
				_shaderFog.FogEnabled(True)
			Endif
		
		End 

	End 
	
	Field _fogIsEnabled? = False
	
	Method SetPerFrameConstants()
	
		If _shaderMatrices Then 
			_shaderMatrices.ViewMatrix(_cam.mod_mat)	
			_shaderMatrices.ProjectionMatrix(_cam.proj_mat)
		End 
		
		If _shaderFog Then 
			_shaderFog.FogEnabled(_cam.fog_mode>0)
			_shaderFog.FogRange(_cam.fog_range_near, _cam.fog_range_far)
			_shaderFog.FogColor( _cam.fog_r,_cam.fog_g,_cam.fog_b)
		End 
		
		If _shaderLights Then 

			_shaderLights.ClearLights()

			For Local light:= Eachin _lights
				_shaderLights.AddLight(light)
			End 
		End 
		
	End
	
	'' Switches the used shader and 
	'' initializes the constants of the new shader, if necessary.
	Method UpdateShader?(shader:TShader)
	
		If shader <> _shader Then 
			
			_shader 		= XNAShader(shader)
			_shaderFog 		= IShaderFog(_shader)
			_shaderColor 	= IShaderColor(_shader)
			_shaderTexture 	= IShaderTexture(_shader)
			_shaderLights 	= IShaderLights(_shader)
			_shaderMatrices = IShaderMatrices(_shader)
			
			' init constants if necessary
			If _shader Then 
			
				_shader.Bind()
			
				If Not _initializedShader.Contains(shader.shader_id) Then 
			
					_initializedShader.Set(shader.shader_id,shader)
					
					SetPerFrameConstants()
					SetPerObjConstants()
					
				End 
				
			End 

			Return True 
		End 
		
		Return False
	End
	
	Method SetTextures(surf:TSurface, ent:TEntity, skip_sprite_state?)
	
		Local tex_count:Int =ent.brush.no_texs
		If surf.brush.no_texs>tex_count Then tex_count=surf.brush.no_texs

		If _shaderTexture Then 
		
			If tex_count = 0 Then 
				
				_shaderTexture.TexturesEnabled(False)
					
			Else
	
				_shaderTexture.TexturesEnabled(True)
				_shaderTexture.TextureCount(1)'tex_count)
				
				For Local ix=0 To tex_count-1			
					
					Local texture:TTexture,tex_flags,tex_blend,tex_coords,tex_u_scale#,tex_v_scale#
					Local tex_u_pos#,tex_v_pos#,tex_ang#,tex_cube_mode,frame, tex_smooth
					
					If surf.brush.tex[ix]<>Null Or ent.brush.tex[ix]<>Null
		
						' Main brush texture takes precedent over surface brush texture
						If ent.brush.tex[ix]<>Null
							texture=ent.brush.tex[ix]
							tex_flags=ent.brush.tex[ix].flags
							tex_blend=ent.brush.tex[ix].blend
							tex_coords=ent.brush.tex[ix].coords
							tex_u_scale=ent.brush.tex[ix].u_scale
							tex_v_scale=ent.brush.tex[ix].v_scale
							tex_u_pos=ent.brush.tex[ix].u_pos
							tex_v_pos=ent.brush.tex[ix].v_pos
							tex_ang=ent.brush.tex[ix].angle
							tex_cube_mode=ent.brush.tex[ix].cube_mode
							frame=ent.brush.tex[ix].tex_frame
							tex_smooth = ent.brush.tex[ix].tex_smooth	
		
						Else
							texture=surf.brush.tex[ix]
							tex_flags=surf.brush.tex[ix].flags
							tex_blend=surf.brush.tex[ix].blend
							tex_coords=surf.brush.tex[ix].coords
							tex_u_scale=surf.brush.tex[ix].u_scale
							tex_v_scale=surf.brush.tex[ix].v_scale
							tex_u_pos=surf.brush.tex[ix].u_pos
							tex_v_pos=surf.brush.tex[ix].v_pos
							tex_ang=surf.brush.tex[ix].angle
							tex_cube_mode=surf.brush.tex[ix].cube_mode
							frame=surf.brush.tex[ix].tex_frame
							tex_smooth = surf.brush.tex[ix].tex_smooth		
						Endif
		
										 
						Local xnaTex:= _textureMap.Get(texture.gltex[0])
						
						''assuming sprites with same surfaces are identical, preserve states---------
						'If Not skip_sprite_state
						
							' filter
							Local filter:UVSamplerState 
							If tex_smooth
								filter = _st_uvSmooth
							Else
								filter = _st_uvNormal
							Endif
							
							Local state:XNASamplerState
							If tex_flags&16 And tex_flags&32 Then ' clamp u clamp v flag
								state = filter._cU_cV
							Elseif tex_flags&16 'clamp u flag
								state = filter._cU_wV
							Elseif tex_flags&32 'clamp v flag
								state = filter._wU_cV
							Elseif tex_count>0 
								state = filter._wU_wV ''only use wrap with power-of-two textures 							
							End
							
							
							_device.SamplerState(ix, state)
							
						'Endif ''end preserve skip_sprite_state-------------------------------
		
						_device.SetTexture(ix, xnaTex)
						_shaderTexture.TextureBlend(ix, tex_blend)
						_shaderTexture.TextureTransform(ix, tex_u_pos,tex_v_pos, tex_u_scale, tex_v_scale , tex_ang,tex_coords)
		
					Endif ''end if tex[ix]
				
				Next 'end texture loop

			End 
		End 
		
	End 

End 
