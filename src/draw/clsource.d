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

kernel void update( global uint* map, const uint4 esize,
                    global float8* pnts, const uint count,
                    const float16 mtr )
{
    int i = get_global_id(0);
    int sz = get_global_size(0);

    uint3 size = (uint3)(esize.xyz);

    for( ; i < count; i+=sz )
    {
        float3 mfrom = mlt( mtr, pnts[i].s012 );
        float3 p = mlt( mtr, pnts[i].s456 );
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
