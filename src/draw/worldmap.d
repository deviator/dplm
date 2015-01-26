module draw.worldmap;

import std.stdio;
import std.conv;

import des.space;
import des.util.helpers;

import draw.object.base;

import draw.compute;

import model.mapaccess;

import std.conv : to;

class CLWorldMap : BaseDrawObject, MapAccess
{
protected:

    CLGLEnv env;

    CalcBuffer dmap;

    MapElement[] map_init;

    CalcBuffer mapreg;

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

    size_t est_step = 1024;
    CalcBuffer known, estres, varres;

    uivec2 unitcamres;
    size_t unitcount;

    Resolver resolver;

    float cur_time;

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

    void setTime( float tm ) { cur_time = tm; }

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
                                      cur_time,
                                      vec4( pos, cam.far ),
                                      uivec2( unitcamres ),
                                      unitpoints, matrix.inv );

        env.releaseAllToGL();
    }

    struct Estimate
    {
        float time = 0;
        uint known;
        float pknown = 0;
        float[2] meas = [0,0];
        float[2] ts = [0,0];
        vec2[2] val;
    }

    auto estimate()
    {
        env.prog.kernel["estimate"]( [est_step], [32],
                dmap, cast(uint)dmap.elementCount,
                known, estres, cur_time );
        env.releaseAllToGL();

        int fknown = 0;

        import des.util.data;

        known.bind();
        auto buf_known = getTypedArray!uint( est_step, known.map() );
        estres.bind();
        auto buf_ests = getTypedArray!MapElement( est_step, estres.map() );

        Estimate te;
        te.time = cur_time;

        foreach( i; 0 .. est_step )
        {
            fknown += buf_known[i];

            te.meas[0] += buf_ests[i].meas;
            te.ts[0] += buf_ests[i].ts;
            te.val[0] += buf_ests[i].val;
        }

        known.bind(); known.unmap();
        estres.bind(); estres.unmap();

        te.known = fknown;
        te.pknown = fknown / cast(float)( dmap.elementCount );

        te.meas[0] /= fknown;
        te.ts[0] /= fknown;
        te.val[0] /= fknown;

        env.prog.kernel["variance"]( [est_step], [32],
                dmap, cast(uint)dmap.elementCount,
                vec4( te.meas[0], te.ts[0], te.val[0] ), varres,
                cur_time );
        env.releaseAllToGL();

        varres.bind();
        auto buf_vars = getTypedArray!vec4( est_step, varres.map() );

        foreach( i; 0 .. est_step )
        {
            te.meas[1] += buf_vars[i].x;
            te.ts[1] += buf_vars[i].y;
            te.val[1] += vec2( buf_vars[i].zw );
        }

        varres.bind(); varres.unmap();

        te.meas[1] /= fknown - 1;
        te.ts[1] /= fknown - 1;
        te.val[1] /= fknown - 1;

        return te;
    }

    protected void updateUnitData()
    {
        auto cnt = unitcount * unitcamres.x * unitcamres.y;
        if( cnt != unitpoints.elementCount )
            unitpoints.setData( new vec4[](cnt) );
    }

    void process() { }

    void setUnitCount( size_t cnt ) { unitcount = cnt; }
    void setUnitCamResolution( in uivec2 cr ) { unitcamres = cr; }

    MapRegion getRegion( in fRegion3 reg )
    {
        auto img_reg = iRegion3( trRegion( matrix.inv, reg ) );
        auto map_reg = iRegion3( ivec3(0), mres );

        auto ov_reg = map_reg.overlap( img_reg );

        return MapRegion( trRegion( matrix, fRegion3( ov_reg ) ),
                          Image3( ov_reg.size,
                                  ElemInfo( DataType.RAWBYTE, MapElement.sizeof ),
                                  getMapData( ov_reg ) ) );
    }

    @property
    {
        ivec3 size() const { return mres; }
        vec3 cellSize() const 
        { return vec3( (matrix * vec4(1,1,1,0)).xyz ); }
    }

    override void draw( Camera cam )
    {
        shader.setUniform!mat4( "prj", cam.projection.matrix * cam.resolve(this) );
        shader.setUniform!int( "size_x", cast(int)mres.x );
        shader.setUniform!int( "size_y", cast(int)mres.y );
        shader.setUniform!float( "time", cur_time );
        //shader.setUniform!float( "psize", 0.03 );

        glEnable( GL_PROGRAM_POINT_SIZE );
        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    void[] getMapData( in iRegion3 vol )
    {
        auto count = cast(uint)( vol.size.x * vol.size.y * vol.size.z );

        if( count == 0 ) return [];
        
        uint[8] volume = to!(uint[])(vol.pos.data) ~ 0 ~
                         to!(uint[])(vol.size.data) ~ 0;

        mapreg.setData( map_init[0..count] );

        env.prog.kernel["getVolume"]( [32], [8],
                dmap, uivec4( mres, 0 ),
                mapreg, volume, count );

        env.releaseAllToGL();

        return mapreg.getUntypedData();
    }

    static fRegion3 trRegion( in mat4 m, in fRegion3 reg )
    {
        return fRegion3( ( m * vec4( reg.pos, 1 ) ).xyz,
                         ( m * vec4( reg.size, 0 ) ).xyz );
    }

    override void prepareBuffers()
    {
        auto cnt = mres.x * mres.y * mres.z;

        dmap = newCalcBuffer();
        connect( dmap.elementCountCB, &setDrawCount );

        auto loc = shader.getAttribLocations( "meas", "ts", "val" );
        setAttribPointer( dmap, loc[0], 1, GLType.UNSIGNED_INT, MapElement.sizeof, 0 );
        setAttribPointer( dmap, loc[1], 1, GLType.FLOAT, MapElement.sizeof, MapElement.ts.offsetof );
        setAttribPointer( dmap, loc[2], 2, GLType.FLOAT, MapElement.sizeof, MapElement.val.offsetof );
        map_init = new MapElement[]( cnt );
        dmap.setData( map_init );

        unitdepth = newCalcBuffer();

        mapreg = newCalcBuffer();

        known = newCalcBuffer();
        known.setData( new uint[](est_step) );
        estres = newCalcBuffer();
        estres.setData( new MapElement[](est_step) );
        varres = newCalcBuffer();
        varres.setData( new vec4[](est_step) );
    }

    CalcBuffer newCalcBuffer() { return newEMM!CalcBuffer( env ); }

    mat4 resolve( SpaceNode obj ) { return resolver( obj, null ); }
}
