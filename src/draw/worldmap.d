module draw.worldmap;

import std.stdio;

public import draw.object.base;
import model.worldmap;

import std.conv;
import des.cl;
import des.cl.helpers;

class CLWorldMap : BaseDrawObject, WorldMap
{
protected:
    class GLCLBuffer : GLBuffer
    {
        CLGLMemory clmem;

        this(T)( T[] data )
        {
            super( Target.ARRAY_BUFFER );
            setData( data );
            createCLMem();
        }

        void createCLMem()
        {
            clmem = registerCLRef( CLGLMemory.createFromGLBuffer( ctx,
                        CLMemory.Flags.READ_WRITE, this ) );
        }

        void acquireFromGL()
        { clmem.acquireFromGL( cmdqueue ); }

        void releaseToGL()
        { clmem.releaseToGL( cmdqueue ); }
    }

    GLCLBuffer data, pnts;

    mat4 mapmtr;
    mapsize_t mres;

    CLGLContext ctx;
    CLCommandQueue cmdqueue;

    CLKernel update;

public:

    this( ivec3 res, vec3 cell )
    {
        /+ TODO: true mapmtr +/
        matrix = mat4.diag( cell, 1 ).setCol(3, vec4(-res,1) );
        mres = mapsize_t(res*2);
        prepareCL();

        super( null, SS_WorldMap );

        warn_if_empty = false;
    }

    void setPoints( in vec3 from, in vec3[] ppt )
    {
        pnts.setData( [from] ~ ppt );

        auto transform = mapmtr.inv * matrix.inv;

        glFlush();
        glFinish();

        data.acquireFromGL();
        pnts.acquireFromGL();

        update.setArgs( data.clmem, to!(uint[4])( mres.data ~ 0 ),
                        pnts.clmem, cast(uint)pnts.elementCount,
                        cast(float[16])transform.asArray[0..16]
                       );
        update.exec( cmdqueue, 1, [0], [32], [16] );

        pnts.releaseToGL();
        data.releaseToGL();

        cmdqueue.flush();
    }

    mapsize_t size() const { return mres; }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniform!int( "size_x", cast(int)mres.w );
        shader.setUniform!int( "size_y", cast(int)mres.h );
        shader.setUniform!float( "psize", 0.03 );

        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    void prepareCL()
    {
        auto platform = CLPlatform.getAll()[0];

        auto devices = registerCLRef( CLDevice.getAll( platform ) );

        ctx = registerCLRef( new CLGLContext( platform ) );
        ctx.initializeFromType( CLDevice.Type.GPU );

        cmdqueue = registerCLRef( new CLCommandQueue( ctx, devices[0] ) );
        auto program = registerCLRef( CLProgram.createWithSource( ctx, CLSource ) );

        try program.build( devices, [ CLBuildOption.fastRelaxedMath ] );
        catch( CLException e )
        {
            stderr.writeln( program.buildInfo()[0] );
            throw e;
        }

        update = registerCLRef( new CLKernel( program, "update" ) );
    }

    CLReference[] clrefs;

    auto registerCLRef(T)( T[] objs ) if( is( T : CLReference ) )
    {
        foreach( obj; objs )
            clrefs ~= cast(CLReference)obj;
        return objs;
    }

    auto registerCLRef(T)( T obj ) if( is( T : CLReference ) )
    {
        clrefs ~= cast(CLReference)obj;
        return obj;
    }

    void destroyCLRefs()
    {
        foreach( obj; clrefs )
            obj.release();
    }

    override void selfDestroy()
    {
        destroyCLRefs();
        super.selfDestroy();
    }

    override void prepareBuffers()
    {
        auto cnt = mres.w * mres.h * mres.d;

        data = registerChildEMM( new GLCLBuffer( new int[](cnt) ) );
        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( data, loc, 1, GLType.INT );

        pnts = registerChildEMM( new GLCLBuffer( new vec3[](1) ) );
    }
}

enum CLSource = 
`
inline float3 mlt( const float16 m, float3 v )
{
    return (float3)( 
    m.s0 * v.x + m.s1 * v.y + m.s2 * v.z + m.s3,
    m.s4 * v.x + m.s5 * v.y + m.s6 * v.z + m.s7,
    m.s8 * v.x + m.s9 * v.y + m.sa * v.z + m.sA );
}

inline bool inRegionI( const uint3 size, const uint3 pnt )
{
    return pnt.x >= 0 && pnt.x < size.x &&
           pnt.y >= 0 && pnt.y < size.y &&
           pnt.z >= 0 && pnt.z < size.z;
}

inline bool inRegionF( const uint3 size, const float3 pnt )
{
    return pnt.x >= 0 && pnt.x < size.x &&
           pnt.y >= 0 && pnt.y < size.y &&
           pnt.z >= 0 && pnt.z < size.z;
}

inline size_t index( const uint3 size, const uint3 pnt )
{ return pnt.x + pnt.y * size.x + pnt.z * size.x * size.y; }

kernel void update( global uint* map, const uint4 esize,
                    global float3* pnts, const uint count,
                    const float16 mtr )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

    uint3 size = (uint3)(esize.xyz);

    float3 mfrom = mlt( mtr, pnts[0] );
    for( ; i < count+1; i+=sz )
    {
        float3 p = mlt( mtr, pnts[i] );
        float3 vv = p - mfrom;

        uint3 crd = (uint3)( p.x, p.y, p.z );
        if( inRegionI( size, crd ) )
        {
            float3 nvv = normalize(vv) * 0.5;
            for( int j = 0; j < fast_length(vv) * 2; j++ )
            {
                float3 v = mfrom + nvv * i;
                uint3 vcrd = (uint3)( v.x, v.y, v.z );
                if( inRegionI( size, vcrd ) )
                    map[index(size,vcrd)] = 1;
            }
            map[index(size,crd)] = 2;
        }
    }
}
`;
