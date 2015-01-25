module draw.object.base;

public import des.gl.simple;
public import des.math.linear;
public import des.space;

public import draw.object.util;
public import draw.compute;

import des.util.logsys;
import std.stdio;

interface DrawNode : SpaceNode
{
    void draw( Camera cam );

    @property
    {
        col4 color() const;
        col4 color( in col4 n );

        bool needDraw() const;
        void needDraw( bool nd );
    }
}

class DrawNodeList : DesObject, DrawNode
{
    mixin SpaceNodeHelper;
protected:
    DrawNode[] list;

    col4 clr;
    bool need_draw = true;

public:

    void draw( Camera cam ) { foreach( obj; list ) obj.draw(cam); }

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

        bool needDraw() const { return need_draw; }
        void needDraw( bool nd )
        {
            need_draw = nd;
            foreach( obj; list )
                obj.needDraw = nd;
        }
    }
}

class BaseDrawObject : GLSimpleObject, DrawNode
{
    mixin SpaceNodeHelper;
protected:

    abstract void prepareBuffers();

    col4 clr;

public:

    this( SpaceNode p, in string sh )
    {
        super( sh );
        spaceParent = p;
        prepareBuffers();
        logger.info( "pass" );
    }

    @property
    {
        col4 color() const { return clr; }
        col4 color( in col4 n ) 
        {
            clr = n;
            logger.trace( "%s", n );
            return clr;
        }

        bool needDraw() const { return draw_flag; }
        void needDraw( bool nd )
        {
            draw_flag = nd;
            logger.Debug( "%s", nd );
        }
    }

    abstract void draw( Camera cam );
}

string readShader( string name )
{
    import std.file;
    import des.util.helpers;
    return readText( appPath( "..", "data", "shaders", name ) );
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
        if( loc[1] < 0 ) logger.warn( "no normal in shader" );
        return loc;
    }

    abstract void fillBuffers();
    abstract void drawFunc();

public:

    this( SpaceNode p )
    {
        import std.file;
        super( p, readShader( "shadeobject.glsl" ) );
        clr = col4( vec3(0.7), 1 );
    }

    override void draw( Camera cam )
    {
        auto rs = cam.resolve(this);

        shader.setUniform!mat4( "prj", cam.projection.matrix * rs );
        shader.setUniform!mat4( "resolve", rs );
        shader.setUniform!vec3( "resolved_light_pos", vec3(0) );
        shader.setUniform!vec4( "color", vec4(clr) );

        glEnable( GL_DEPTH_TEST );

        drawFunc();
    }
}
