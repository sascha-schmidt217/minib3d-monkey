Import minib3d
Import "data/spacer.png"
Import "data/mojo_font2.png"

Public 

Class SpriteBatch

	Const MAX_BATCH_SIZE = 2048
	Const MIN_BATCH_SIZE = 16

	Field _spriteCnt:Int
	Field _ix# = 1,_iy#, _jx#, _jy# = 1,_tx#= 0, _ty# = 0
	Field _r# = 1, _g# = 1, _b# = 1, _a# = 1
	Field _begin?
	Field _mesh:TMesh 
	Field _surface:TSurface
	Field _primTex:TTexture 
	Field _pad:TTexture
	Field tformed?
	
	Method New()

		' init mesh
		_mesh = CreateMesh(MAX_BATCH_SIZE)
		_surface = _mesh.GetSurface(1)
		_mesh.name ="spritebatch"
		
		' init camera
		TRender.camera2D.CameraViewport(0,0,TRender.width,TRender.height)
		TRender.camera2D.SetPixelCamera
		TRender.camera2D.CameraClsMode(False,True)
		TRender.camera2D.draw2D = 1
		
		' init texture stages
		' _pad is also used for drawRect, drawLine, drawOval
		_pad = LoadTexture("spacer.png",2+16+32)
		Self.Draw(_pad,-1,-1)
	End
	
	Field wireframeIsEnabled? = False
	
	Method BeginRender:Void()

		TRender.render.Reset()
		TRender.render.SetDrawShader()
		TRender.render.UpdateCamera(TRender.render.camera2D)
		TRender.alpha_pass = 1
		
		_mesh.brush.blend = 1
		_mesh.Update(TRender.camera2D ) 

		_begin = True 
		
		wireframeIsEnabled = TRender.wireframe
		Wireframe(False)
		
		ClearBatch()
		
	End
	
	Method SetBlend(blend)
		RenderBatch(_primTex)
		ClearBatch()
		
		Select blend
			Case AdditiveBlend
				_mesh.brush.blend = 3
			Default
				_mesh.brush.blend = 1
		End 
	End 

	Method EndRender:Void()

		RenderBatch(_primTex)
		ClearBatch()
		
		TShader.DefaultShader()
		TRender.render.Reset()

		_begin = False 
		
		Wireframe(wireframeIsEnabled)
	End

	Method SetScissor(x#,y#,width#,height#)
	
		RenderBatch(_primTex)
		ClearBatch()
		
		TRender.camera2D.CameraViewport(x,y,width,height)
		TRender.render.UpdateCamera(TRender.camera2D)
		_mesh.Update(TRender.camera2D )
		 
	End 
	
	Method SetColor:Void(r#,g#,b#)
		_r = r
		_g = g
		_b = b
	End 

	Method SetAlpha:Void(a#)
		_a = a
	End 

	Method SetMatrix(ix#,iy#,jx#,jy#,tx#,ty#)
		_ix = ix
		_iy = iy
		_jx = jx
		_jy = jy
		_tx = tx
		_ty = ty
		tformed=(ix<>1 Or iy<>0 Or jx<>0 Or jy<>1 Or tx<>0 Or ty<>0)
	End 

	Method Draw:Void(texture:TTexture,x:Float, y:Float)

		__Draw2(texture,x, y, texture.width, texture.height, 0,0,1,1 )

	End
	
	Method Draw:Void( texture:TTexture,x#,y#,width#, height#,srcX#,srcY#,srcWidth#,srcHeight#)

		Local w# = texture.width
		Local h# = texture.height
		Local u0# = srcX / w
		Local v0# = srcY / h
		Local u1# = (srcX + srcWidth ) / w
		Local v1# = (srcY + srcHeight ) / h

		__Draw2(texture,x, y,width, height, u0,v0,u1,v1)
	End 

	Method __Draw2:Void(texture:TTexture,x#, y#,w#,h#, u0# , v0#, u1# , v1# )

		If _primTex <> texture Or _spriteCnt = MAX_BATCH_SIZE Then 
		
			RenderBatch(_primTex)
			ClearBatch()
			_primTex = texture
			
			If _primTex = Null Then' if called from B2DDrawRect
				_primTex = _pad
			End
			
		End 

		Local x0#=x,x1#=x+w,x2#=x+w,x3#=x
		Local y0#=y,y1#=y,y2#=y+h,y3#=y+h
		Local tx0#=x0,tx1#=x1,tx2#=x2,tx3#=x3
		
		If tformed Then 
			x0=tx0 * _ix + y0 * _jx + _tx
			y0=tx0 * _iy + y0 * _jy + _ty
			x1=tx1 * _ix + y1 * _jx + _tx
			y1=tx1 * _iy + y1 * _jy + _ty
			x2=tx2 * _ix + y2 * _jx + _tx
			y2=tx2 * _iy + y2 * _jy + _ty
			x3=tx3 * _ix + y3 * _jx + _tx
			y3=tx3 * _iy + y3 * _jy + _ty
		End 

		Local vid:Int = _surface.no_verts
		
		_surface.vert_data.PokeVertCoords(vid,x0,y0,0)
		_surface.vert_data.PokeTexCoords(vid, u0,v0,0,0)		
		_surface.vert_data.PokeColor(vid,_r, _g, _b, _a)

		vid+= 1

		_surface.vert_data.PokeVertCoords(vid,x1,y1,0)
		_surface.vert_data.PokeTexCoords(vid, u1,v0,0,0)		
		_surface.vert_data.PokeColor(vid, _r, _g, _b, _a)

		vid+= 1

		_surface.vert_data.PokeVertCoords(vid,x2,y2,0)
		_surface.vert_data.PokeTexCoords(vid, u1,v1,0,0)		
		_surface.vert_data.PokeColor(vid, _r, _g, _b, _a)

		vid+= 1

		_surface.vert_data.PokeVertCoords(vid,x3,y3,0)
		_surface.vert_data.PokeTexCoords(vid, u0,v1,0,0)		
		_surface.vert_data.PokeColor(vid, _r, _g, _b, _a)

		_surface.no_verts+=4
		_surface.no_tris+=2
		_spriteCnt+=1

	End 
	
	Method DrawLine:Void(x0#, y0#, x1#, y1#, linewidth# = 1)
	
		If _primTex <> _pad Or _spriteCnt = MAX_BATCH_SIZE Then 
		
			RenderBatch(_primTex)
			ClearBatch()
			_primTex = _pad
			
		End 

		Local dx# = (x1-x0)
		Local dy# = (y1-y0)
		Local length# = Sqrt(dx*dx+dy*dy)
		Local angle# = (ATan2(dy, dx) + 360.0) Mod 360.0
		local s# = Sin(angle)
		Local c# = Cos(angle)
		
		Local w# = length
		Local h# = linewidth
		Local x# = 0
		Local y# = 0
		Local tx# = x0
		Local ty# = y0
		
		x0=x;x1=x+w;y0=y;y1=y
		Local x2#=x+w,x3#=x
		Local y2#=y+h,y3#=y+h
		Local tx0#=x0,tx1#=x1,tx2#=x2,tx3#=x3
		
		x0=tx0 * c + y0 * -s + tx
		y0=tx0 * s + y0 * c + ty
		x1=tx1 * c + y1 * -s + tx 
		y1=tx1 * s + y1 * c + ty 
		x2=tx2 * c + y2 * -s + tx
		y2=tx2 * s + y2 * c + ty 
		x3=tx3 * c + y3 * -s + tx
		y3=tx3 * s + y3 * c + ty 
	
		If tformed Then 
		
			tx0=x0;tx1=x1;tx2=x2;tx3=x3
			
			x0=tx0 * _ix + y0 * _jx + _tx
			y0=tx0 * _iy + y0 * _jy + _ty
			x1=tx1 * _ix + y1 * _jx + _tx
			y1=tx1 * _iy + y1 * _jy + _ty
			x2=tx2 * _ix + y2 * _jx + _tx
			y2=tx2 * _iy + y2 * _jy + _ty
			x3=tx3 * _ix + y3 * _jx + _tx
			y3=tx3 * _iy + y3 * _jy + _ty
			
		End 

		Local vid:Int = _surface.no_verts
		
		_surface.vert_data.PokeVertCoords(vid,x0,y0,0)	
		_surface.vert_data.PokeColor(vid,_r, _g, _b, _a); vid+= 1
		_surface.vert_data.PokeVertCoords(vid,x1,y1,0)		
		_surface.vert_data.PokeColor(vid, _r, _g, _b, _a); vid+= 1
		_surface.vert_data.PokeVertCoords(vid,x2,y2,0)		
		_surface.vert_data.PokeColor(vid, _r, _g, _b, _a);vid+= 1
		_surface.vert_data.PokeVertCoords(vid,x3,y3,0)
		_surface.vert_data.PokeColor(vid, _r, _g, _b, _a)

		_surface.no_verts+=4
		_surface.no_tris+=2
		_spriteCnt+=1
		
	End 
	
	Method DrawOval(x#,y#,w#,h#)
	
		RenderBatch(_primTex)
		ClearBatch()
		_primTex = _pad
		
		Local xr#=w/2.0
		Local yr#=h/2.0
	
		local segs;
		If tformed Then
			Local dx_x#=xr * _ix
			Local dx_y#=xr * _iy
			Local dx#=Sqrt( dx_x*dx_x+dx_y*dx_y )
			Local dy_x#=yr * _jx
			Local dy_y#=yr * _jy
			Local dy#=Sqrt( dy_x*dy_x+dy_y*dy_y )
			segs=int( dx+dy )
		else
			segs=int( Abs( xr )+Abs( yr ) );
		End 
		
		if segs<12 then
			segs=12
		else if segs>MAX_BATCH_SIZE then
			segs=MAX_BATCH_SIZE
		else
			segs&=~3;
		End 
		
		x+=xr;
		y+=yr;
		
		For Local i=0 Until segs-1

			Local sq# = 360.0 / segs
			
			Local x0#=x
			Local y0#=y
					
			Local th#=i * sq;
			Local x1#=x+Cos( th ) * xr;
			Local y1#=y-Sin( th ) * yr;
			
			th=(i+1) * sq;
			Local x2#=x+Cos( th ) * xr;
			Local y2#=y-Sin( th) * yr;
			
			th=(i+2) * sq;
			Local x3#=x+Cos( th ) * xr;
			Local y3#=y-Sin( th) * yr;
			
			Local tx0#=x0,tx1#=x1,tx2#=x2,tx3#=x3;
			
			If tformed 
				x0=tx0 * _ix + y0 * _jx + _tx;
				y0=tx0 * _iy + y0 * _jy + _ty;
				x1=tx1 * _ix + y1 * _jx + _tx;
				y1=tx1 * _iy + y1 * _jy + _ty;
				x2=tx2 * _ix + y2 * _jx + _tx;
				y2=tx2 * _iy + y2 * _jy + _ty;
				x3=tx3 * _ix + y3 * _jx + _tx;
				y3=tx3 * _iy + y3 * _jy + _ty;
			End  

			_surface.vert_data.PokeVertCoords(_surface.no_verts,x0,y0,0)	
			_surface.vert_data.PokeColor(_surface.no_verts,_r, _g, _b, 1)
			_surface.no_verts+=1
			
			_surface.vert_data.PokeVertCoords(_surface.no_verts,x1,y1,0)	
			_surface.vert_data.PokeColor(_surface.no_verts,_r, _g, _b, 1)
			_surface.no_verts+=1
			
			_surface.vert_data.PokeVertCoords(_surface.no_verts,x2,y2,0)	
			_surface.vert_data.PokeColor(_surface.no_verts,_r, _g, _b, 1)
			_surface.no_verts+=1
			
			_surface.vert_data.PokeVertCoords(_surface.no_verts,x3,y3,0)	
			_surface.vert_data.PokeColor(_surface.no_verts,_r, _g, _b, 1)
			_surface.no_verts+=1
			
			_surface.no_tris+=2
		End 
		
		'' set texture
		_mesh.brush.tex[0]=null
		_mesh.brush.no_texs=0
		
		' render
		TRender.camera2D.draw2D = 1
		TRender.render.Render(_mesh,TRender.render.camera2D)
		
		ClearBatch()
	End 
Private 

	Method CreateMesh:TMesh(size)

		Local mesh:= New TMesh
		mesh.is_update = True 
		mesh.ScaleEntity (1,-1,1)
		mesh.PositionEntity(- TRender.width*0.5,TRender.height*0.5, 1.99999)
		mesh.EntityFX( 1+2+8+16+32+64)
		mesh.EntityBlend(1)
	
		'' create static sized surface
		Local surf:= mesh.CreateSurface()
		surf.vert_data= CopyDataBuffer(surf.vert_data, VertexDataBuffer.Create(size*4) )
		surf.vert_array_size = size
		surf.no_verts = 0
		surf.tris =CopyShortBuffer(surf.tris, ShortBuffer.Create(size*2*3) )
		surf.tri_array_size = size*2*3
		surf.no_tris = 0
	
		'' precreate all indices
		'' indexbuffers won't be touched anymore this way!
		For Local i = 0 until size
			Local v0 = i*4
			surf.AddTriangle(0+v0,1+v0,2+v0)
			surf.AddTriangle(0+v0,2+v0,3+v0)
		Next
		surf.no_tris = 0
		
		' Alpha() needs to be called after .CreateSurface!
		If mesh.Alpha() Then mesh.alpha_order = 1

		Return mesh
	End

	Method ClearBatch:Void()
		_surface.reset_vbo = -1
		_surface.no_tris = 0
		_surface.no_verts = 0
		_spriteCnt = 0
	End
	
	Method RenderBatch:Void(tex:TTexture)

		If _spriteCnt = 0 Then Return 
		
		'' set texture
		_mesh.brush.tex[0]=tex
		If tex Then 
			_mesh.brush.no_texs=1
		Else
			_mesh.brush.no_texs=0
		End 
		
		' render
		TRender.camera2D.draw2D = 1
		TRender.render.Render(_mesh,TRender.render.camera2D)
	End 

End


