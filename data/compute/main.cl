inline float4 mlt( const float16 m, float4 v )
{
    return (float4)( dot( m.s0123, v ),
                     dot( m.s4567, v ),
                     dot( m.s89AB, v ),
                     dot( m.sCDEF, v ) );
}

inline float3 project( const float16 m, float3 p )
{
    float4 b = mlt( m, (float4)(p,1) );
    return b.xyz / b.w;
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

inline uint3 coordinate( const uint3 size, size_t ind )
{
    uint3 ret;
    ret.z = ind / (size.x * size.y);
    int k = ind % ( size.x * size.y );
    ret.y = k / size.x;
    ret.x = k % size.x;
    return ret;
}

kernel void depthToPoint( global float* depth,
                          const uint2 camres,
                          const float camfar,
                          const float16 ud_persp_inv,
                          const float16 ud_transform,
                          global float4* points,
                          const uint unitid )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

    uint pcnt = camres.x * camres.y;
    uint pstart = pcnt * unitid;

    for( ; i < pcnt; i += sz )
    {
        uint ix = i % camres.x;
        uint iy = i / camres.x;

        float fx = (ix+0.5f) / camres.x * 2 - 1;
        float fy = (iy+0.5f) / camres.y * 2 - 1;

        float d = depth[i] * 2.0 - 1;

        float3 bg = project( ud_persp_inv, (float3)(fx,fy,d) );

        float fp = (depth[i] < 1.0f-1e-5) ? 1.0f : 0.0f;

        bg = project( ud_transform, bg );

        points[pstart+i] = (float4)(bg,fp);
    }
}

kernel void updateMap( global float* map, const uint4 esize,
                       const uint unitid,
                       const float4 ud_pos,
                       const uint2 camres,
                       global float4* points, const float16 tomap )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

    uint3 size = (uint3)(esize.xyz);
    uint pcnt = camres.x * camres.y;
    uint pstart = pcnt * unitid;

    for( ; i < pcnt; i+=sz )
    {
        float4 bg = points[pstart+i];

        float3 a = project( tomap, ud_pos.xyz );
        float3 b = project( tomap, bg.xyz );

        float3 dir = b - a;

        float3 fstep = normalize(dir);
        float lendir = fast_length(dir);

        for( float j = 0; j < lendir; j+=0.5 )
        {
            float3 v = a + fstep * j;

            uint mapind = index(size,(uint3)(v.x,v.y,v.z));
            if( inRegionF(size,v) && map[mapind] != map[mapind] )
                map[mapind] = 0;
        }

        if( inRegionF( size, b ) && bg.w > 0 )
            map[index( size, (uint3)( b.x, b.y, b.z ) )] = 1;
    }
}

int isKnown( float val ) { return val == val ? 1 : 0; }

kernel void estimateKnown( global float* map, global int* known, const uint count )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);
    int st = count / sz;

    known[i] = 0;

    for( int j = 0; j < st; j++ )
        known[i] += isKnown( map[i*st+j] );
}

kernel void nearfind( global float* map, const uint4 esize,
                      const uint count, const uint8 volume, global float4* near )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

    uint3 msize = (uint3)(esize.xyz);

    uint3 vpos = (uint3)(volume.s012);
    uint3 vsize = (uint3)(volume.s456);
    
    for( ; i < count; i+=sz )
    {
        uint3 crd = vpos + coordinate( vsize, i );
        if( inRegionI( msize, crd ) )
            near[i] = (float4)( crd.x, crd.y, crd.z, map[index(msize,crd)] );
        else
            near[i] = (float4)(0);
    }
}
