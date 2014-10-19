module draw.clsource;

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

kernel void update( global float* map, const uint4 esize,
                    global float8* pnts, const uint count,
                    const float16 mtr )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

    uint3 size = (uint3)(esize.xyz);

    for( ; i < count; i+=sz )
    {
        float3 a = mlt( mtr, pnts[i].s012 );
        float3 b = mlt( mtr, pnts[i].s456 );

        float3 dir = b - a;

        float3 fstep = normalize(dir);

        for( float j = 0; j < fast_length(dir); j+=0.5 )
        {
            float3 v = a + fstep * j;

            if( inRegionF( size, v ) )
                map[index( size, (uint3)( v.x, v.y, v.z ) )] = 0;
        }

        if( inRegionF( size, b ) && pnts[i].s7 > 0 )
            map[index( size, (uint3)( b.x, b.y, b.z ) )] = 1;
    }
}
`;
