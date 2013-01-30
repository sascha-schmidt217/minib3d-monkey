Import brl
Import minib3d
Import minib3d.driver

Class XNAShader extends TShader implements IShader 

	Global Device:XNAGraphicsDevice
	
Private 

	Global SHADER_ID = 0

	Field _effect:XNAEffect
	Field _technique:XNAEffectTechnique
	Field _pass:XNAEffectPass
	Field _variables:= New ShaderParameterCollection

Public 
	
	Method New()
		SHADER_ID+=1
		shader_id = SHADER_ID
	End 
	
	Method Load( effectFile:String)
	
		if _effect Then 
			_effect.Dispose()
			_effect = null
		Endif
		
		_effect = Device.LoadEffect(effectFile)
		_technique = _effect.GetTechnique(0)
		_pass = _technique.Passes[0]
		
		'' init parameter collection
		
		Local param_count = _effect.CountParameters()
		For Local i = 0 Until param_count
			Local param:= _effect.GetParameter(i)
			_variables.AddLast(New XNAShaderParameter(param))
		End 

		PrintShader(Self)
	End 

	''
	'' TShader
	''
	
	Method Copy:TBrush()
		
		Local brush:= New XNAShader
	
		brush.no_texs=no_texs
		brush.name=name
		brush.red=red
		brush.green=green
		brush.blue=blue
		brush.alpha=alpha
		brush.shine=shine
		brush.blend=blend
		brush.fx=fx
		brush.tex[0]=tex[0]
		brush.tex[1]=tex[1]
		brush.tex[2]=tex[2]
		brush.tex[3]=tex[3]
		brush.tex[4]=tex[4]
		brush.tex[5]=tex[5]
		brush.tex[6]=tex[6]
		brush.tex[7]=tex[7]
						
		' is this enough?
		brush._effect = _effect
		brush._technique = _technique
		brush._pass = _pass
		brush._variables = _variables

		Return brush
	End 
	
	''
	'' IShader
	''
	
	Method Parameters:ShaderParameterCollection() Property
		Return _variables
	End 
	
	Method Apply()
		_pass.Apply()
	End 
	
	Method Bind()
		' is done automatically in xna using .Apply
	End 
	
	Method Release()
		if _effect Then 
			_effect.Dispose()
			_effect = null
		Endif
	End 
	
	Method Name:String()
		Return _effect.Name
	End 
End 

 '----------------------------------------------------------

Class XNAShaderParameter implements IShaderParameter 
Private 

	' precreated arrays
	Global _int2%[2]
	Global _int3%[3]
	Global _int4%[4]
	Global _float2#[2]
	Global _float3#[3]
	Global _float4#[4]
	Global _bool2?[2]
	Global _bool3?[3]
	Global _bool4?[4]
	Global _float4x4#[16]
	
	Field _name:String 
	Field _parameterType:Int 
	Field _parameterClass:Int 
	Field _elements:IShaderParameter[]
	Field _structureMembers:IShaderParameter[]
	Field _rowCount%
	Field _columnCount%
	
	' the xna effect parameter
	Field _parameter:XNAEffectParameter
	
Public 

	Method New(parameter:XNAEffectParameter)
		_parameter = parameter
		_name = parameter.Name

		Select parameter.ParameterType
			Case EFFECT_PARAMETER_TYPE_BOOL
				_parameterType = EFFECT_PARAMETER_TYPE_BOOL
			Case EFFECT_PARAMETER_TYPE_INT32
				_parameterType = SHADER_PARAMETER_TYPE_INT
			Case EFFECT_PARAMETER_TYPE_SINGLE
				_parameterType = SHADER_PARAMETER_TYPE_FLOAT
			Case EFFECT_PARAMETER_TYPE_STRING
				_parameterType = SHADER_PARAMETER_TYPE_STRING
			Case EFFECT_PARAMETER_TYPE_TEXTURE
				_parameterType = SHADER_PARAMETER_TYPE_TEXTURE
			Case EFFECT_PARAMETER_TYPE_TEXTURE1D
				_parameterType = SHADER_PARAMETER_TYPE_TEXTURE1D
			Case EFFECT_PARAMETER_TYPE_TEXTURE2D
				_parameterType = SHADER_PARAMETER_TYPE_TEXTURE2D
			Case EFFECT_PARAMETER_TYPE_TEXTURE3D
				_parameterType = SHADER_PARAMETER_TYPE_TEXTURE3D
			Case EFFECT_PARAMETER_TYPE_TEXTURECUBE
				_parameterType = SHADER_PARAMETER_TYPE_TEXTURECUBE
			Case EFFECT_PARAMETER_TYPE_VOID
				_parameterType = EFFECT_PARAMETER_TYPE_BOOL
		End 
	
		Select parameter.ParameterClass
			Case EFFECT_PARAMETER_CLASS_MATRIX 
				_parameterClass = SHADER_PARAMETER_CLASS_MATRIX_ROWS
			Case EFFECT_PARAMETER_CLASS_OBJECT 
				_parameterClass = SHADER_PARAMETER_CLASS_OBJECT
			Case EFFECT_PARAMETER_CLASS_SCALAR 
				_parameterClass = SHADER_PARAMETER_CLASS_SCALAR
			Case EFFECT_PARAMETER_CLASS_STRUCT 	
				_parameterClass = SHADER_PARAMETER_CLASS_STRUCT
			Case EFFECT_PARAMETER_CLASS_VECTOR 
				_parameterClass = SHADER_PARAMETER_CLASS_VECTOR
		End 
		
		Local elements:= parameter.Elements 
		_elements = _elements.Resize(elements.Length )
		For Local i = 0 Until elements.Length 
			' why cast here? That suchs!
			_elements[i] = IShaderParameter(New  XNAShaderParameter(elements[i]))
		End 
		
		Local structureMember:= parameter.StructureMembers
		_structureMembers = _structureMembers.Resize(structureMember.Length)
		For Local i = 0 Until  structureMember.Length 
			' why cast here? That suchs!
			_structureMembers[i] = IShaderParameter(New XNAShaderParameter(structureMember[i]))
		End 
	End 

	Method RowCount:Int() Property 
		Return _rowCount
	End 
	
	Method ColumnCount() Property
		Return _columnCount
	End 
	
	Method Name:String() Property 
		Return _name
	End 
	
	Method ParameterType:Int() Property 
		Return _parameterType
	End 
	
	Method ParameterClass:Int() Property 
		Return _parameterClass
	End 

	Method Elements:IShaderParameter[]() Property 
		Return _elements
	End 
	
	Method StructureMembers:IShaderParameter[]() Property 
		Return _structureMembers
	End 
	
	Method SetValue:Void(value:Vector) 
		_float3[0] = value.x
		_float3[1] = value.y
		_float3[2] = value.z
		_parameter.SetValue(_float3)
	End 
	
	Method SetValue:Void(value:Matrix) 
		For Local row:= 0 Until 4; For Local column:= 0 Until 4 
			_float4x4[column * 4 + row] = value.grid[column][row]
		End;End 
		_parameter.SetValue(_float4x4)
	End 
	
	Method SetValue:Void(value:Int[]) 
		_parameter.SetValue(value)
	End 
	
	Method SetValue:Void(value:Float[]) 
		_parameter.SetValue(value)
	End 
	 
	Method SetValue:Void(v0#) 
		_parameter.SetValue(v0)
	End 
	
	Method SetValue:Void(v0#,v1#) 
		_float2[0] = v0
		_float2[1] = v1
		_parameter.SetValue(_float2)
	End 
	 
	Method SetValue:Void(v0#,v1#,v2#) 
		_float3[0] = v0
		_float3[1] = v1
		_float3[2] = v2
		_parameter.SetValue(_float3)
	End 
	
	Method SetValue:Void(v0#,v1#,v2#,v3#) 
		_float4[0] = v0
		_float4[1] = v1
		_float4[2] = v2
		_float4[3] = v3
		_parameter.SetValue(_float4)
	End 
	
	Method SetValue:Void(v0%) 
		_parameter.SetValue(v0)
	End 
	
	Method SetValue:Void(v0%,v1%) 
		_int2[0] = v0
		_int2[1] = v1
		_parameter.SetValue(_int2)
	End 
	 
	Method SetValue:Void(v0%,v1%,v2%) 
		_int3[0] = v0
		_int3[1] = v1
		_int3[2] = v2
		_parameter.SetValue(_int3)
	End 
	
	Method SetValue:Void(v0%,v1%,v2%,v3%) 
		_int4[0] = v0
		_int4[1] = v1
		_int4[2] = v2
		_int4[3] = v3
		_parameter.SetValue(_int4)
	End 
	
	Method SetValue:Void(v0?)
		_parameter.SetValue(v0)
	End 
	
	Method SetValue:Void(v0?,v1?)
		_bool2[0] = v0
		_bool2[1] = v1
		_parameter.SetValue(_bool2)
	End 
	
	Method SetValue:Void(v0?,v1?,v2?)
		_bool3[0] = v0
		_bool3[1] = v1
		_bool3[2] = v2
		_parameter.SetValue(_bool3)
	End 
	
	Method SetValue:Void(v0?,v1?,v2?, v3?)
		_bool4[0] = v0
		_bool4[1] = v1
		_bool4[2] = v2
		_bool4[3] = v3
		_parameter.SetValue(_bool4)
	End 
	
End