constant float2 depth_correct_table[100] = {
(float2)( 0, 0.5 ),
(float2)( 0.0392157, 0.51 ),
(float2)( 0.0582524, 0.515 ),
(float2)( 0.0769231, 0.52 ),
(float2)( 0.0952381, 0.525 ),
(float2)( 0.113208, 0.53 ),
(float2)( 0.130841, 0.535 ),
(float2)( 0.148148, 0.54 ),
(float2)( 0.165138, 0.545 ),
(float2)( 0.181818, 0.549999 ),
(float2)( 0.198198, 0.554999 ),
(float2)( 0.214286, 0.559999 ),
(float2)( 0.230089, 0.564999 ),
(float2)( 0.245614, 0.569999 ),
(float2)( 0.26087, 0.574999 ),
(float2)( 0.275862, 0.579999 ),
(float2)( 0.290599, 0.584999 ),
(float2)( 0.305085, 0.589999 ),
(float2)( 0.319328, 0.594999 ),
(float2)( 0.333334, 0.599999 ),
(float2)( 0.347108, 0.604999 ),
(float2)( 0.360656, 0.609999 ),
(float2)( 0.373984, 0.614999 ),
(float2)( 0.387098, 0.619999 ),
(float2)( 0.400001, 0.624999 ),
(float2)( 0.4127, 0.629998 ),
(float2)( 0.425198, 0.634999 ),
(float2)( 0.437501, 0.639998 ),
(float2)( 0.449614, 0.644998 ),
(float2)( 0.46154, 0.649998 ),
(float2)( 0.473283, 0.654999 ),
(float2)( 0.48485, 0.659998 ),
(float2)( 0.496242, 0.664998 ),
(float2)( 0.507464, 0.669998 ),
(float2)( 0.51852, 0.674998 ),
(float2)( 0.529413, 0.679998 ),
(float2)( 0.540148, 0.684998 ),
(float2)( 0.550726, 0.689998 ),
(float2)( 0.561153, 0.694998 ),
(float2)( 0.571431, 0.699998 ),
(float2)( 0.581561, 0.704999 ),
(float2)( 0.591551, 0.709998 ),
(float2)( 0.601401, 0.714997 ),
(float2)( 0.611113, 0.719998 ),
(float2)( 0.620693, 0.724996 ),
(float2)( 0.630138, 0.729998 ),
(float2)( 0.639458, 0.734998 ),
(float2)( 0.648651, 0.739998 ),
(float2)( 0.65772, 0.744998 ),
(float2)( 0.666669, 0.749997 ),
(float2)( 0.6755, 0.754997 ),
(float2)( 0.684213, 0.759997 ),
(float2)( 0.692814, 0.764996 ),
(float2)( 0.701301, 0.769998 ),
(float2)( 0.70968, 0.774998 ),
(float2)( 0.717952, 0.779997 ),
(float2)( 0.726117, 0.784997 ),
(float2)( 0.73418, 0.789997 ),
(float2)( 0.742141, 0.794997 ),
(float2)( 0.750003, 0.799997 ),
(float2)( 0.757767, 0.804996 ),
(float2)( 0.765435, 0.809997 ),
(float2)( 0.773009, 0.814997 ),
(float2)( 0.780491, 0.819997 ),
(float2)( 0.787881, 0.824998 ),
(float2)( 0.795184, 0.829996 ),
(float2)( 0.8024, 0.834995 ),
(float2)( 0.809527, 0.839997 ),
(float2)( 0.816571, 0.844996 ),
(float2)( 0.823533, 0.849996 ),
(float2)( 0.830412, 0.854997 ),
(float2)( 0.837213, 0.859997 ),
(float2)( 0.843935, 0.864996 ),
(float2)( 0.850579, 0.869996 ),
(float2)( 0.857147, 0.874996 ),
(float2)( 0.86364, 0.879997 ),
(float2)( 0.870059, 0.884997 ),
(float2)( 0.876408, 0.889996 ),
(float2)( 0.882685, 0.894997 ),
(float2)( 0.888893, 0.899996 ),
(float2)( 0.895032, 0.904996 ),
(float2)( 0.901102, 0.909997 ),
(float2)( 0.907109, 0.914994 ),
(float2)( 0.913047, 0.919996 ),
(float2)( 0.918923, 0.924996 ),
(float2)( 0.924735, 0.929996 ),
(float2)( 0.930486, 0.934995 ),
(float2)( 0.936175, 0.939995 ),
(float2)( 0.941803, 0.944995 ),
(float2)( 0.947373, 0.949995 ),
(float2)( 0.952884, 0.954996 ),
(float2)( 0.958337, 0.959997 ),
(float2)( 0.963734, 0.964996 ),
(float2)( 0.969075, 0.969997 ),
(float2)( 0.974364, 0.974994 ),
(float2)( 0.979597, 0.979995 ),
(float2)( 0.984778, 0.984994 ),
(float2)( 0.989904, 0.989995 ),
(float2)( 0.994981, 0.994994 ),
(float2)( 1, 1 )
};

inline float getDepthCorrect( float v )
{
    if( v < 0 ) return 0.5;
    if( v > 1 ) return 1;
    int l = 0;
    int r = 99;
    while( r - l > 1 )
    {
        int p = (l+r)/2;
        if( depth_correct_table[p].x > v )
            r = p;
        else l = p;
    }

    float2 a = depth_correct_table[l];
    float2 b = depth_correct_table[r];

    float k = (v - a.x) / (b.x - a.x);
    return a.y * (1 - k) + b.y * k;
}

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

        float3 bg = project( ud_persp_inv, (float3)(fx,fy,depth[i]) );

        float fp = (depth[i] < 1.0f-1e-5) ? 1.0f : 0.0f;

        bg *= getDepthCorrect( fabs(bg.z/camfar) );
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
