
''
'' - implements also IShader, basically the same as D3D11DefaultShader!!
''

Import minib3d
Import "effects\default.fx"

Class XNADefaultShader Extends XNAShader Implements  IShaderColor, IShaderTexture, IShaderLights, IShaderMatrices, IShaderFog

Private 

	Const SHADER_FILENAME$ = "default.fx"
	Const MAX_LIGHTS = 4
	Const MAX_TEXTURES = 4
	Const DEG_TO_RAD:Float = 0.0174532925199432957692369076848861
	Const ENABLE_FOG 			=  1	
	Const ENABLE_LIGHTING 		=  2	
	Const ENABLE_TEXTURE 		=  4	
	Const ENABLE_VERTEXCOLOR 	=  8	
	
	'' light settings are cached and updated through .Update()
	Field _lightCount = 0
	Field _updateLights? = False
	Field _lights:= New List<TLight>
	Field _dirLights:= New List<TLight>
	Field _spotLights:= New List<TLight>
	Field _pointLights:= New List<TLight>
	Field _shaderIndex:Int 
	
	' used to indicate shader permutation
	Field _pShaderIndex:IShaderParameter
	
	'' IShaderMatrices
	Field _pView:IShaderParameter
	Field _pProj:IShaderParameter
	Field _pWorld:IShaderParameter
	
	'' IShaderLights
	Field _pLightType:IShaderParameter[8]
	Field _pLightPos:IShaderParameter[8]
	Field _pLightDir:IShaderParameter[8]
	Field _pLightColor:IShaderParameter[8]
	Field _pLightRange:IShaderParameter[8]
	Field _pLightInner:IShaderParameter[8]
	Field _pLightAuter:IShaderParameter[8]
	Field _pLightDirIni:IShaderParameter
	Field _pLightDirNum:IShaderParameter
	Field _pLightSpotIni:IShaderParameter
	Field _pLightSpotNum:IShaderParameter
	Field _pLightPointIni:IShaderParameter
	Field _pLightPointNum:IShaderParameter
	Field _pEyePosition:IShaderParameter
	Field _pLightCount:IShaderParameter
	
	'' IShaderFog
	Field _pFogNear:IShaderParameter
	Field _pFogFar:IShaderParameter
	Field _pFogColor:IShaderParameter
	
	'' IShaderTexture
	Field _pTextureCount:IShaderParameter
	Field _pTextureScale:IShaderParameter[8]
	Field _pTexturePosition:IShaderParameter[8]
	Field _pTextureBlend:IShaderParameter[8]
	Field _pTextureCoords:IShaderParameter[8]
	Field _pTextureAngles:IShaderParameter[8]
	
	'' IShaderColor
	Field _pVertexColorEnabled:IShaderParameter
	Field _pDiffuseColor:IShaderParameter
	Field _pAmbientColor:IShaderParameter
	Field _pShininess:IShaderParameter
	 
Public 

	Method New()
		Super.Load(SHADER_FILENAME)

		_pShaderIndex = Parameters.Get("shaderIndex")
		
		'' IShaderMatrices
	  	_pView = Parameters.Get("view")
		_pProj = Parameters.Get("projection")
		_pWorld = Parameters.Get("world")
		
		'' IShaderLights
		Local lights:= Parameters.Get("lights").Elements 
		For Local i = 0 Until lights.Length
			Local lp:= lights[i].StructureMembers
			_pLightPos[i]		= lp[0]
			_pLightRange[i]		= lp[1]
			_pLightDir[i]		= lp[2]
			_pLightInner[i]		= lp[3]
			_pLightColor[i]		= lp[4]
			_pLightAuter[i]		= lp[5]
			_pLightType[i]		= lp[6]
		Next	
		
		_pLightDirIni		= Parameters.Get("iLightDirIni")	
		_pLightDirNum		= Parameters.Get("iLightDirNum")	
		_pLightPointIni		= Parameters.Get("iLightPointIni")	
		_pLightPointNum		= Parameters.Get("iLightPointNum")	
		_pLightSpotIni		= Parameters.Get("iLightSpotIni")	
		_pLightSpotNum		= Parameters.Get("iLightSpotNum")
		_pEyePosition		= Parameters.Get("eyePosition")
		
		'' IShaderFog
		_pFogNear 		= Parameters.Get("fogNear")	
		_pFogFar 		= Parameters.Get("fogFar")	
		_pFogColor 		= Parameters.Get("fogColor")
		
		'' texture params
		_pTextureCount = Parameters.Get("textureCount")
		Local texStages:=  Parameters.Get("textureStages").Elements 
		For Local i = 0 until texStages.Length
			Local lp:= texStages[i].StructureMembers
			_pTextureScale[i] 		=  lp[0]' scale
			_pTexturePosition[i] 	=  lp[1]' offset
			_pTextureBlend[i] 		=  lp[2]' blend
			_pTextureCoords[i] 		=  lp[3]' coords
			_pTextureAngles[i] 		=  lp[4]' angle
		End 
		
		'' color params
		_pDiffuseColor =  Parameters.Get("diffuseColor")
		_pAmbientColor =  Parameters.Get("ambientColor")
		_pShininess =  Parameters.Get("shininess")
		
	End
	
	'' IShaderMatrices
	
	Method ProjectionMatrix(m:Matrix)
		_pProj.SetValue(m)
	End 

	Method ViewMatrix(m:Matrix)
		_pView.SetValue(m)
	End 
	
	Method WorldMatrix(m:Matrix)
		_pWorld.SetValue(m)
	End 

	'' IShaderLights
	
	Method LightingEnabled(val?)  
		If val
			_shaderIndex |= ENABLE_LIGHTING
		Else
			_shaderIndex &= (~ENABLE_LIGHTING)
		End  
	End 

	Method AddLight(light:TLight)  
		If _lightCount = MAX_LIGHTS Then 
			_lights.RemoveFirst()
			_lightCount-=1
		End 
		_lights.AddLast(light)
		_updateLights = True
		_lightCount+=1
	End 
	
	Method DisableLight(light:TLight)  
		If _lights.Coontains(light) Then 
			_lights.Remove(light)
			_lightCount-=1
			_updateLights = True
		End 
	End 
	
	Method ClearLights()
		_lights.Clear()
		_lightCount = 0
		_updateLights = True
	End 
	
	Method EyePosition(x#,y#,z#)
		_pEyePosition.SetValue(x,y,z)
	End 
	
	'' IShaderTexture
	
	Method TexturesEnabled(val?) 
		If val
			_shaderIndex |= ENABLE_TEXTURE
		Else
			_shaderIndex &= (~ENABLE_TEXTURE)
		End 
	End 
	 
	Method TextureBlend(index, blend)  
		_pTextureBlend[index].SetValue(blend)
	End 	

	Method TextureCount(count)  
		_pTextureCount.SetValue(count)
	End 
	
	Method TextureTransform(index, tex_u_pos#,tex_v_pos#, tex_u_scale#, tex_v_scale# , tex_ang#, coords)
		_pTextureScale[index].SetValue( tex_u_scale, tex_v_scale)
		_pTexturePosition[index].SetValue( tex_u_pos, tex_v_pos)
		_pTextureCoords[index].SetValue( coords)
		_pTextureAngles[index].SetValue( Cos(tex_ang), Sin(tex_ang))
	End 
	
	'' IShaderBaseColor

	Method VertexColorEnabled(val?)
		If val
			_shaderIndex |= ENABLE_VERTEXCOLOR
		Else
			_shaderIndex &= (~ENABLE_VERTEXCOLOR)
		End 
	End 
	  
	Method DiffuseColor(r:Float,g:Float,b:Float,a:Float)  
		_pDiffuseColor.SetValue(r,g,b,a)
	End 
	   
	Method AmbientColor(r:Float,g:Float,b:Float)  
		_pAmbientColor.SetValue(r,g,b)
	End 
	  
	Method Shine(val:Float)
		_pShininess.SetValue(val)
	End 
	    
	Method ShinePower(val:Float) '??
	End 
	   
	'' IShaderFog
	
	Method FogEnabled(val?)
		If val
			_shaderIndex |= ENABLE_FOG
		Else
			_shaderIndex &= (~ENABLE_FOG)
		End 
	End 
	    
	Method FogColor(r#,g#,b:Float)    
		_pFogColor.SetValue(r ,g ,b)
	End 

	Method FogRange(near#,far# )
		_pFogNear.SetValue(near)
		_pFogFar.SetValue(far)
	End 
	 
	'' TShader
	
	Method Update()
	
		''  enable proper shader permutation
		_pShaderIndex.SetValue(_shaderIndex)
		
		If _shaderIndex & ENABLE_LIGHTING And _updateLights Then 
			_updateLights = False
			
			_dirLights.Clear()
			_spotLights.Clear()
			_pointLights.Clear()
			
			Local dirCount  	= 0
			Local pointCount 	= 0
			Local spotCount  	= 0

			For Local light:= Eachin _lights
				Select light.light_type
					Case 1'dir
						_dirLights.AddLast(light)
						dirCount+=1
					Case 2'point
						_pointLights.AddLast(light)
						pointCount+=1
					Case 3'spot
						_spotLights.AddLast(light)
						spotCount+=1
				End 
			End 
			

			Local index = 0

			_pLightDirIni.SetValue(index)
			_pLightDirNum.SetValue(dirCount)
			
			For Local light:= Eachin _dirLights
			
				Local dir:= New Vector(-light.mat.grid[2][0],-light.mat.grid[2][1],-light.mat.grid[2][2])
				dir = dir.Normalize()
				
				_pLightType[index].SetValue(1)
				_pLightDir[index].SetValue(dir.x,dir.y,dir.z,1.0)
				_pLightColor[index].SetValue(light.red, light.green, light.blue,1.0)
				
				index+=1
			End 

			_pLightPointIni.SetValue(index)
			_pLightPointNum.SetValue(pointCount)
			
			For Local light:= Eachin _pointLights
			
				_pLightType[index].SetValue(2)
				_pLightPos[index].SetValue(light.mat.grid[3][0], light.mat.grid[3][1],light.mat.grid[3][2],1.0)
				_pLightRange[index].SetValue(light.range)
				_pLightColor[index].SetValue(light.red, light.green, light.blue,1.0)
				
				index+=1
			End 
			
			_pLightSpotIni.SetValue(index)
			_pLightSpotNum.SetValue(spotCount)
			
			For Local light:= Eachin _spotLights
			
				Local dir:= New Vector(-light.mat.grid[2][0],-light.mat.grid[2][1],-light.mat.grid[2][2])
				dir = dir.Normalize()
				
				_pLightType[index].SetValue(3)
				_pLightDir[index].SetValue(dir.x,dir.y,dir.z,1.0)
				_pLightPos[index].SetValue(light.mat.grid[3][0], light.mat.grid[3][1],light.mat.grid[3][2],1.0)
				_pLightRange[index].SetValue(light.range)
				_pLightColor[index].SetValue(light.red, light.green, light.blue,1.0)
				_pLightInner[index].SetValue(light.inner_ang*DEG_TO_RAD)
				_pLightAuter[index].SetValue(light.outer_ang*DEG_TO_RAD)
				
				index+=1
			End 
		End 
	End 
	
End