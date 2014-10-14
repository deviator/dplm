module draw.object.base;

public import des.gl.simple;
public import des.math.linear;
public import draw.object.shader;
public import draw.object.util;

import std.stdio;

interface DrawNode : Node
{
    void draw( Camera cam );

    @property
    {
        col4 color() const;
        col4 color( in col4 n );

        mat4 matrix() const;
        mat4 matrix( in mat4 m );

        const(Node) parent() const;
    }

    void setParent( Node p );
}

class DrawNodeList : DrawNode
{
protected:
    Node par;
    mat4 mtr;

    DrawNode[] list;

    col4 clr;

public:

    void draw( Camera cam )
    {
        foreach( obj; list )
            obj.draw(cam);
    }

    @property
    {
        col4 color() const { return clr; }
        col4 color( in col4 n ) 
        {
            clr = n;
            foreach( obj; list )
                obj.color = clr;
            return clr;
        }

        mat4 matrix() const { return mtr; }
        mat4 matrix( in mat4 m )
        { mtr = m; return mtr; }

        const(Node) parent() const { return par; }
    }

    void setParent( Node p ) { par = p; }
}

class BaseDrawObject : GLSimpleObject, DrawNode
{
protected:

    abstract void prepareBuffers();

    col4 clr;

    Node par;
    mat4 mtr;

public:

    this( Node p, in ShaderSource sh )
    {
        super( sh );
        par = p;
        prepareBuffers();
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

    abstract void draw( Camera cam );
}

class BaseShadeObject : BaseDrawObject
{
protected:
    GLBuffer pos, norm;

    override void prepareBuffers()
    {
        auto loc = getLocations();

        pos  = createArrayBuffer();
        setAttribPointer( pos, loc[0], 3, GLType.FLOAT );

        if( loc[1] >= 0 )
        {
            norm = createArrayBuffer();
            setAttribPointer( norm, loc[1], 3, GLType.FLOAT );
        }

        fillBuffers();
    }

    auto getLocations()
    {
        auto loc = shader.getAttribLocations( "position", "normal" );
        if( loc[0] < 0 ) assert( 0, "no position in shader" );
        if( loc[1] < 0 ) stderr.writeln( "no normal in shader" );
        return loc;
    }

    abstract void fillBuffers();
    abstract void drawFunc();

public:

    this( Node p )
    {
        super( p, SS_ShadeObject );
        clr = col4( vec3(0.7), 1 );
    }

    override void draw( Camera cam )
    {
        auto rs = cam.resolve(this);

        shader.setUniformMat( "prj", cam(this) );
        shader.setUniformMat( "resolve", rs );
        shader.setUniformVec( "resolved_light_pos", (vec4(0,0,0,1)).xyz );
        shader.setUniformVec( "color", clr );

        glEnable( GL_DEPTH_TEST );

        drawFunc();
    }
}
