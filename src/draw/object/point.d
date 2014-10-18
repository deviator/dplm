module draw.object.point;

public import draw.object.base;

class Point : BaseDrawObject
{
protected:
    GLBuffer pos;

    vec3[] data;

public:

    this( Node p )
    {
        super( p, SS_Simple );
        clr = col4( 0,1,0, 1 );
        warn_if_empty = false;
    }

    void set( vec3[] p )
    {
        data = p.dup;
        updateBuffer();
    }

    void add( vec3[] p )
    {
        data ~= p;
        updateBuffer();
    }

    void reset() { data.length = 0; }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformVec( "color", clr );

        glPointSize(2);
        if( data.length )
            drawArrays( DrawMode.POINTS );
    }

protected:

    void updateBuffer()
    {
        if( data.length )
            pos.setData( data );
    }

    override void prepareBuffers()
    {
        auto b = createArrayBuffersFromAttributeInfo(
                APInfo( "position", 3, GLType.FLOAT ) );

        pos = b["position"];
    }
}

