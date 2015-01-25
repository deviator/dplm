module draw.worldmap;

import std.stdio;
import std.conv;

import des.space;
import des.il.region;
import des.util.helpers;

import draw.object.base;

import draw.compute;

class CLWorldMap : BaseDrawObject
{
protected:

    CLGLEnv env;

    CalcBuffer dmap;

    CalcBuffer near;

    alias Vector!(8,uint) VolumeData;

    mat4 mapmtr;
    ivec3 mres;

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

    uivec2 unitcamres;
    size_t unitcount;

    Resolver resolver;

public:

    this( CLGLEnv e, ivec3 res, vec3 cell, CalcBuffer unitpts )
    in
    {
        assert( e !is null );
        assert( unitpts !is null );
    }
    body
    {
        env = e;

        unitpoints = unitpts;

        mapmtr = mat4.diag( cell, 1 ).setCol( 3, vec4( vec2(-res.xy)*cell.xy, 0, 1 ) );
        mres = ivec3( res.xy*2, res.z );

        super( null, readShader( "worldmap_light.glsl" ) );

        resolver = new Resolver;
    }

    void updateMap( size_t unitid, SimpleCamera cam, in float[] depth )
    {
        auto transform = resolve( cam );
        auto pos = vec3( transform.col(3)[0..3] );

        updateUnitData();
        unitdepth.setData( depth );

        env.prog.kernel["depthToPoint"]( [1024], [32],
                                         unitdepth,
                                         uivec2( unitcamres ),
                                         cam.far,
                                         cam.projection.matrix.inv,
                                         transform,
                                         unitpoints,
                                         cast(uint)unitid );

        env.prog.kernel["updateMap"]( [1024], [32],
                                      dmap, uivec4( mres, 0 ),
                                      cast(uint)unitid,
                                      vec4( pos, cam.far ),
                                      uivec2( unitcamres ),
                                      unitpoints, matrix.inv );

        env.releaseAllToGL();
    }

    protected void updateUnitData()
    {
        auto cnt = unitcount * unitcamres.x * unitcamres.y;
        if( cnt != unitpoints.elementCount )
            unitpoints.setData( new vec4[](cnt) );
    }

    void process() { }

    void setUnitCamResolution( in uivec2 cr ) { unitcamres = cr; }

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

        env.prog.kernel["nearfind"]( [32], [8],
                                     dmap, uivec4( mres, 0 ),
                            cast(uint)count, volume, near );

        env.releaseAllToGL();

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
        return vec3( (matrix * vec4(mpos,0)).xyz );
    }

    protected auto getRegion( in mat4 m, in vec3 pos, float dst )
    {
        auto pmin = ivec3( (m * vec4( pos - vec3(dst), 1 ) ).xyz );
        auto size = ivec3( (m * vec4( vec3(dst) * 2, 0 ) ).xyz );

        auto dvol = iRegion3( ivec3(0), mres );
        auto cvol = iRegion3( pmin, size );

        return dvol.overlap( cvol );
    }

    @property ivec3 size() const { return mres; }
    @property vec3 cellSize() const 
    { return vec3( (matrix * vec4(1,1,1,0)).xyz ); }

    override void draw( Camera cam )
    {
        shader.setUniform!mat4( "prj", cam.projection.matrix * cam.resolve(this) );
        shader.setUniform!int( "size_x", cast(int)mres.x );
        shader.setUniform!int( "size_y", cast(int)mres.y );
        //shader.setUniform!float( "psize", 0.03 );

        glEnable( GL_PROGRAM_POINT_SIZE );
        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    override void prepareBuffers()
    {
        auto cnt = mres.x * mres.y * mres.z;

        dmap = newEMM!CalcBuffer( env );
        connect( dmap.elementCountCB, &setDrawCount );

        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( dmap, loc, 1, GLType.FLOAT );
        dmap.setData( new float[](cnt) );

        unitdepth = newEMM!CalcBuffer( env );

        near = newEMM!CalcBuffer( env );
    }

    mat4 resolve( SpaceNode obj ) { return resolver( obj, null ); }
}
