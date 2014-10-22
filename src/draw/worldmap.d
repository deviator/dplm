module draw.worldmap;

import std.stdio;
import std.conv;

import des.cl.glsimple;

import des.il.region;

public import draw.object.base;
import draw.calcbuffer;
import model.dataaccess;

import des.util.helpers;

enum CLSourceWithKernels = staticLoadCLSource!"cl/main.cl";

class CLWorldMap : BaseDrawObject, ModelDataAccess
{
protected:

    CalcBuffer dmap;

    CalcBuffer near;

    alias Vector!(8,uint) VolumeData;

    mat4 mapmtr;
    mapsize_t mres;

    SimpleCLKernel[string] kernel;

    struct UnitData
    {
        mat4 persp_inv,
             transform;

        vec3 pos;
        float camfar;

        this( in vec3 p, float cf, in mat4 pi, in mat4 tr )
        {
            pos = p;
            camfar = cf;
            persp_inv = pi;
            transform = tr;
        }
    }

    CalcBuffer unitdepth, unitpoints;

    ivec2 unitcamres;
    size_t unitcount;

public:

    this( ivec3 res, vec3 cell, CalcBuffer unitpts )
    {
        mapmtr = mat4.diag( cell, 1 ).setCol(3, vec4(vec2(-res.xy)*cell.xy,0,1) );
        mres = mapsize_t(res.xy*2,res.z);
        prepareCL();

        super( null, SS_WorldMap_M );

        unitpoints = unitpts;
    }

    void updateMap( size_t unitid, in mat4 persp, float camfar,
                      in mat4 transform, in float[] depth )
    {
        auto pos = vec3(transform.col(3)[0..3]);

        updateUnitData();
        unitdepth.setData( depth );

        CLGL.acquireFromGL( dmap, unitdepth, unitpoints );

        kernel["updateMap"].setArgs( dmap, uivec4(mres,0),
                                     cast(uint)unitid,
                                     vec4( pos, camfar ),
                                     persp.inv,
                                     mat4( transform ),
                                     unitdepth, uivec2(unitcamres),
                                     unitpoints, matrix.inv );
        kernel["updateMap"].exec( 1, [0], [1024], [32] );
        CLGL.releaseToGL();
    }

    protected void updateUnitData()
    {
        auto cnt = unitcount * unitcamres.x * unitcamres.y;
        if( cnt != unitpoints.elementCount )
            unitpoints.setData( new vec4[](cnt) );
    }

    void process() { }

    void setUnitCamResolution( in ivec2 cr ) { unitcamres = cr; }

    void setUnitCount( size_t cnt ) { unitcount = cnt; }

    vec4[] getPoints( in vec3 pos, float dst )
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

        CLGL.acquireFromGL( dmap, near );

        kernel["nearfind"].setArgs( dmap, uivec4( mres, 0 ),
                            cast(uint)count, volume, near );

        kernel["nearfind"].exec( 1, [0], [32], [8] );

        CLGL.releaseToGL();

        auto nearbuf = near.getData!vec4;

        vec4[] ret;
        foreach( n; nearbuf )
            ret ~= vec4( (matrix * vec4(n.xyz,1)).xyz, n.w );

        return ret;
    }

    vec3 nearestVolume( in vec3 pos )
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

    @property mapsize_t size() const { return mres; }
    @property vec3 cellSize() const 
    { return (matrix * vec4(1,1,1,0)).xyz; }

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

    void prepareCL() { kernel = CLGL.build( CLSourceWithKernels ); }

    override void selfDestroy()
    {
        CLGL.systemDestroy();
        super.selfDestroy();
    }

    override void prepareBuffers()
    {
        auto cnt = mres.w * mres.h * mres.d;

        dmap = registerChildEMM( new CalcBuffer() );
        dmap.elementCountCallback = &setDrawCount;

        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( dmap, loc, 1, GLType.FLOAT );
        dmap.setData( new float[](cnt) );

        unitdepth = registerChildEMM( new CalcBuffer() );

        near = registerChildEMM( new CalcBuffer() );
    }
}
