module draw.worldmap;

import std.stdio;
import std.conv;

import des.cl.glsimple;

import des.il.region;

public import draw.object.base;
import model.worldmap;

import des.util.helpers;

enum CLSource = import( "cl/main.cl" );

class CLWorldMap : BaseDrawObject, WorldMap
{
protected:

    class MainDataBuffer : GLArrayBuffer, CLMemoryBuffer
    {
        mixin( getCLMemProperty );

        this(T)( string name, uint cnt, GLType type, T[] data )
        {
            super();
            auto loc = shader.getAttribLocation( name );
            setAttribPointer( this, loc, cnt, type );
            setData( data );

            clInit();
        }
    }

    class SBuffer : GLBuffer, CLMemoryBuffer
    {
        mixin( getCLMemProperty );

        this()
        {
            super( Target.ARRAY_BUFFER );
            setData( [0] );

            clInit();
        }
    }

    MainDataBuffer data;

    SBuffer pnts, near;

    alias Vector!(8,float) PntData;
    alias Vector!(8,uint) VolumeData;
    PntData[] pnts_tmp_data;

    mat4 mapmtr;
    mapsize_t mres;

    SimpleCLKernel update;
    SimpleCLKernel nearfind;

public:

    this( ivec3 res, vec3 cell )
    {
        mapmtr = mat4.diag( cell, 1 ).setCol(3, vec4(vec2(-res.xy)*cell.xy,0,1) );
        mres = mapsize_t(res.xy*2,res.z);
        prepareCL();

        super( null, SS_WorldMap_M );
    }

    void setPoints( in vec3 from, in vec4[] ppt )
    {
        foreach( pnt; ppt )
            pnts_tmp_data ~= PntData( from, 0.0f, pnt );
    }

    vec4[] getFillPoints( in vec3 pos, float dst )
    {
        auto m = matrix.inv;

        auto vol = getRegion( m, pos, dst );
        auto count = vol.size.x * vol.size.y * vol.size.z;

        if( count == 0 ) return [];

        uint[8] volume = [
            cast(uint)vol.pos.x,
            cast(uint)vol.pos.y,
            cast(uint)vol.pos.z,
            0,
            cast(uint)vol.size.x,
            cast(uint)vol.size.y,
            cast(uint)vol.size.z,
            0
        ];

        near.setData( new vec4[](count) );

        CLGL.acquireFromGL( data, near );

        nearfind.setArgs( data, uivec4( mres, 0 ),
                        cast(uint)count, volume, near );

        nearfind.exec( 1, [0], [32], [8] );

        CLGL.releaseToGL();

        auto nearbuf = near.getData!vec4;

        vec4[] ret;
        foreach( n; nearbuf )
            ret ~= vec4( (matrix * vec4(n.xyz,1)).xyz, n.w );

        return ret;
    }

    vec3 nearestVolume( vec3 pos )
    {
        auto mpos = ( matrix.inv * vec4( pos, 1 ) ).xyz;
        foreach( i; 0 .. 3 )
        {
            if( mpos[i] < 0 ) mpos[i] = -mpos[i];
            else if( mpos[i] >= mres[i] ) mpos[i] = mres[i] - mpos[i];
            else mpos[i] = 0;
        }
        return (matrix * vec4(mpos,0)).xyz;
    }

    protected auto getRegion( in mat4 m, in vec3 pos, float dst )
    {
        auto pmin = ivec3( (m * vec4( pos - vec3(dst), 1 ) ).xyz );
        auto size = ivec3( (m * vec4( vec3(dst) * 2, 0 ) ).xyz );

        auto dvol = iRegion3( ivec3(0), mres );
        auto cvol = iRegion3( pmin, size );

        return dvol.overlap( cvol );
    }

    void process()
    {
        if( !loadTmp() ) return;

        auto transform = matrix.inv;

        CLGL.acquireFromGL( data, pnts );

        update.setArgs( data, uivec4(mres,0),
                        pnts, cast(uint)pnts.elementCount,
                        transform );
        update.exec( 1, [0], [1024], [32] );

        CLGL.releaseToGL();
    }

    protected bool loadTmp()
    {
        if( pnts_tmp_data.length == 0 ) return false;
        pnts.setData( pnts_tmp_data );
        pnts_tmp_data.length = 0;
        return true;
    }

    mapsize_t size() const { return mres; }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniform!int( "size_x", cast(int)mres.w );
        shader.setUniform!int( "size_y", cast(int)mres.h );
        shader.setUniform!float( "psize", 0.03 );

        glEnable(GL_PROGRAM_POINT_SIZE);
        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    void prepareCL()
    {
        auto kernels = CLGL.build( CLSource, "update", "nearfind" );
        update = kernels["update"];
        nearfind = kernels["nearfind"];
    }

    override void selfDestroy()
    {
        CLGL.systemDestroy();
        super.selfDestroy();
    }

    override void prepareBuffers()
    {
        auto cnt = mres.w * mres.h * mres.d;

        data = registerChildEMM( new MainDataBuffer( "data", 1, GLType.FLOAT,
                                                      new float[](cnt) ) );

        pnts = registerChildEMM( new SBuffer() );
        near = registerChildEMM( new SBuffer() );
    }
}
