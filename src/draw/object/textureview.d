module draw.object.textureview;

public import des.gl.simple;
public import des.math.linear;

import des.il;

enum ShaderSource SS_DepthTextureView =
{
`#version 330
in vec2 pos;
in vec2 uv;
out vec2 iuv;
void main()
{
    gl_Position = vec4( pos.xy, -0.1f, 1.0f );
    iuv = uv;
}
`,
`#version 330
in vec2 iuv;
uniform sampler2D depth;
out vec4 color;
void main()
{
    float d = texture( depth, iuv ).r;
    vec3 dv3 = vec3(pow(d,4));
    color = vec4( dv3, 1 );
}
`
};

class TextureView : GLSimpleObject
{
protected:
    GLArrayBuffer[string] pnt;
    GLTexture tex;

    void delegate() predrawfnc;

public:

    this()
    {
        super( SS_DepthTextureView );
        prepareBuffers();
        tex = registerChildEMM( new GLTexture(GLTexture.Target.T2D) );
    }

    void draw( void delegate() fnc=null )
    {
        predrawfnc = fnc;
        drawArrays( DrawMode.TRIANGLE_STRIP );
    }

    void setImage( in Image!2 img )
    {
        import std.stdio;
        import std.math;
        foreach( y; 0 .. img.size.h )
        {
            foreach( x; 0 .. img.size.w )
                writef( " % 4.2f", pow( img.pixel!float(x,y), 4 ) );
            writeln();
        }
        writeln();

        tex.image( img );
    }

protected:

    void prepareBuffers()
    {
        pnt = createArrayBuffersFromAttributeInfo(
                APInfo( "pos", 2, GLType.FLOAT ),
                APInfo( "uv", 2, GLType.FLOAT )
                );

        auto pos_data = [ vec2(1,1), vec2(-1,1), vec2(1,-1), vec2(-1,-1) ];
        auto uv_data = [ vec2(1,1), vec2(0,1), vec2(1,0), vec2(0,0) ];

        pnt["pos"].setData( pos_data, GLBuffer.Usage.STATIC_DRAW );
        pnt["uv"].setData( uv_data, GLBuffer.Usage.STATIC_DRAW );
    }

    override void preDraw()
    {
        super.preDraw();
        if( predrawfnc !is null )
            predrawfnc();
        //tex.bind(0);
        shader.setUniform!int( "ttu", 0 );
        glDisable( GL_DEPTH_TEST );
    }
}
