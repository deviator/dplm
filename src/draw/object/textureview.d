module draw.object.textureview;

public import des.gl.simple;
public import des.math.linear;

import des.il;

enum SS_DepthTextureView = ShaderSource(
`#version 330
in vec2 pos;
in vec2 uv;
uniform float img_ratio;
uniform float view_ratio;
uniform vec2 offset;
uniform vec2 scale;
out vec2 iuv;
void main()
{
    float ratio = img_ratio;
    vec2 p1 = vec2( pos.x , pos.y / img_ratio) * scale;
    vec2 p2 = vec2( p1.x / view_ratio, p1.y ) + offset;
    gl_Position = vec4( p2, -0.1f, 1.0f );
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
    vec3 dv3 = vec3(d);
    color = vec4( dv3, 1 );
}`
);

class TextureView : GLSimpleObject
{
protected:
    GLArrayBuffer[string] pnt;

    void delegate() predrawfnc;

    float img_ratio = 1, view_ratio = 1;
    vec2 offset, scale = vec2(1);

public:

    this()
    {
        super( SS_DepthTextureView );
        prepareBuffers();
    }

    void draw( void delegate() fnc=null )
    {
        predrawfnc = fnc;
        drawArrays( DrawMode.TRIANGLE_STRIP );
    }

    void setImgRatio( float r ) { img_ratio = r; }
    void setViewRatio( float r ) { view_ratio = r; }
    void setOffset( in vec2 o ) { offset = o; }
    void setScale( in vec2 s ) { scale = s; }

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
        shader.setUniform!int( "depth", 0 );
        shader.setUniformVec( "offset", offset );
        shader.setUniformVec( "scale", scale );
        shader.setUniform!float( "img_ratio", img_ratio );
        shader.setUniform!float( "view_ratio", view_ratio );
        glDisable( GL_DEPTH_TEST );
    }
}
