#MINIB3D_DRIVER="xna"

#XNA_PERPIXEL_LIGHNING=True' only used in reach profile
#XNA_PROFILE="reach"
#XNA_MIPMAP_FILTER=1' 0 for point / 1 for linear
#XNA_MIPMAP_QUALITY=2 ' sets bias to 0=0.5, 1=0, 2=-0.5

#If TARGET<>"xna"
	#Error "Need XNA target"
#Endif

#Print "miniB3D XNA"

#If XNA_PROFILE="hidef"
	
	#Print "hidef profile"
	Import minib3d.xna.xna_render_hidef

#Else

	#Print "reach profile"
	Import minib3d.xna.xna_render

#End 

Import xna_driver.xna
Import xna_pixmap
Import xna_shader
Import xna_shader_default

Function SetRender(flags:Int=0)
	
	TRender.render = New XNARender
	TRender.render.GraphicsInit(flags)
	
End



