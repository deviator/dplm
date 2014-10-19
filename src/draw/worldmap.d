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
    GLBuffer data, pnts;

    mat4 mapmtr;
    mapsize_t mres;

    CLGLContext ctx;
    CLGLMemory clmem;
    CLKernel update;
    CLCommandQueue cmdqueue;

public:

    this( ivec3 res, vec3 cell )
    {
        mres = mapsize_t(res*2);
        prepareCL();

        super( null, SS_WorldMap );

        warn_if_empty = false;
    }

    void setPoints( in vec3 from, in vec3[] pnts )
    {
        glFlush();
        clmem.acquireFromGL( cmdqueue );

        //update.setArgs();
        //update.exec( cmdqueue, 1, [0], [1024 * 2], [32] );

        clmem.releaseToGL( cmdqueue );
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
        data = registerChildEMM( new GLBuffer( GLBuffer.Target.ARRAY_BUFFER ) );
        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( data, loc, 1, GLType.INT );
        auto cnt = mres.w * mres.h * mres.d;
        data.setData( new int[](cnt), GLBuffer.Usage.DYNAMIC_DRAW );

        pnts = registerChildEMM( new GLBuffer( GLBuffer.Target.ARRAY_BUFFER ) );

        clmem = CLGLMemory.createFromGLBuffer( ctx, CLMemory.Flags.READ_WRITE, data );
    }
}

enum CLSource = 
`
inline float3 mlt( global float4* m, float3 v )
{
    float4 p = (float4)(v,1);
    return (float3)( dot( m[0], p ),
                     dot( m[1], p ),
                     dot( m[2], p ) );

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

kernel void update( global int* data, const uint3 size, global float3* pnts, const uint count, global float4* mtr )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

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
                    data[index(size,vcrd)] = 1;
            }
            data[index(size,crd)] = 2;
        }
    }
}
`;
