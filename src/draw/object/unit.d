module draw.object.unit;

public import draw.object.base;
import std.math;

class DrawUnit : GLSimpleObject, DrawNode
{
protected:

    GLBuffer pos, norm;

    col4 clr;

    Node par;
    mat4 mtr;

    void fillBuffers()
    {
        auto s1 = 1;
        auto s2 = s1 * 0.2;
        auto s3 = s1 * 0.1;
        auto s4 = s3 / 2;
        auto h = s1 * 0.2;

        auto p0 = vec3(0,0,0);
        auto p1 = vec3(0,0,h);
        auto p2 = vec3(s1,0,0);
        auto p3 = vec3(s2,s2,0);
        auto p4 = vec3(s2,-s2,0);
        auto p5 = vec3(0,0,-h);

        auto p6 = vec3(s1,0,0);

        auto fig = [ p0, p1, p2, p3, p1, p4, p2, p5, p0 ];

        auto pos_data = 
            figure_rot_Z( PI/4, fig ) ~
            figure_rot_Z( PI/4 + PI/2, fig ) ~
            figure_rot_Z( PI/4 + PI, fig ) ~
            figure_rot_Z( PI/4 + 3 * PI / 2, fig ) ~
            figure_rot_Z( PI/4 + 2 * PI, fig ) ~
            [ p6, p6 + vec3(-s3,0,s4), p6 + vec3(-s3,0,-s4),
              p6, p6 + vec3(-s3,s4,0), p6 + vec3(-s3,-s4,0), p6 ];

        pos.setData( pos_data, GLBuffer.Usage.STATIC_DRAW );
    }

public:

    this( Node p )
    {
        super( SS_Simple );
        auto loc = shader.getAttribLocation( "position" );
        if( loc < 0 ) assert( 0, "no position in shader" );

        pos = createArrayBuffer();
        setAttribPointer( pos, loc, 3, GLType.FLOAT );

        par = p;

        clr = col4( 1,0,0,1 );

        fillBuffers();
    }

    void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformVec( "color", clr );

        glEnable( GL_DEPTH_TEST );

        drawArrays( DrawMode.LINE_LOOP );
    }

    @property
    {
        col4 color() const { return clr; }
        col4 color( in col4 n ) 
        { clr = n; return clr; }

        mat4 matrix() const { return mtr; }
        mat4 matrix( in mat4 m )
        { mtr = m; return mtr; }

        const(Node) parent() const { return par; }
    }

    void setParent( Node p ) { par = p; }
}
