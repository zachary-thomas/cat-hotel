Shader "Purrington/Authored Water" {
 Properties { [MainColor] _BaseColor("Deep color",Color)=(0.23,0.57,0.61,1) _ShoreZ("Shore Z",Float)=-1000 }
 SubShader { Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
 Pass { Name "ForwardLit" Tags { "LightMode"="UniversalForward" }
 HLSLPROGRAM
 #pragma vertex Vert
 #pragma fragment Frag
 #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
 #pragma multi_compile_fragment _ _SHADOWS_SOFT
 #pragma multi_compile_instancing
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
 #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 CBUFFER_START(UnityPerMaterial)
 float4 _BaseColor;float _ShoreZ;
 CBUFFER_END
 float _PurringtonMotion;
 struct Attributes {float4 positionOS:POSITION;float3 normalOS:NORMAL;UNITY_VERTEX_INPUT_INSTANCE_ID};
 struct Varyings {float4 positionCS:SV_POSITION;float3 positionWS:TEXCOORD0;half3 normalWS:TEXCOORD1;UNITY_VERTEX_INPUT_INSTANCE_ID UNITY_VERTEX_OUTPUT_STEREO};
 Varyings Vert(Attributes input){Varyings output;UNITY_SETUP_INSTANCE_ID(input);UNITY_TRANSFER_INSTANCE_ID(input,output);UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);VertexPositionInputs pos=GetVertexPositionInputs(input.positionOS.xyz);output.positionCS=pos.positionCS;output.positionWS=pos.positionWS;output.normalWS=TransformObjectToWorldNormal(input.normalOS);return output;}
 half4 Frag(Varyings input):SV_Target {UNITY_SETUP_INSTANCE_ID(input);float t=_Time.y*_PurringtonMotion;float2 p=float2(input.positionWS.x,-input.positionWS.z);float phase=p.y*2.1+sin(p.x*.65+t*.23)*.8-t*.7;float detail=1-smoothstep(.3,1.5,fwidth(phase));float wave=sin(phase);float broken=.55+.45*sin(p.x*.8-p.y*.5+t*.2);float ripple=smoothstep(.82,.98,wave)*broken*detail;float shore=1-smoothstep(0,8,p.y-_ShoreZ);half3 color=lerp(_BaseColor.rgb,half3(.42,.77,.76),shore*.55)+(ripple*.10+wave*detail*.018);Light light=GetMainLight(TransformWorldToShadowCoord(input.positionWS));half3 n=normalize(input.normalWS);half3 illumination=SampleSH(n)+light.color*(saturate(dot(n,light.direction))*light.shadowAttenuation);return half4(color*illumination,1);}
 ENDHLSL
 }
 UsePass "Universal Render Pipeline/Lit/DepthOnly"
 UsePass "Universal Render Pipeline/Lit/DepthNormals"
 }
}


