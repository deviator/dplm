module model.worldmap;

import model.mapdata;

import des.math.linear;

interface WorldMap : Node
{
    alias Vector!(3,size_t,"w h d") mapsize_t;

    void setPoints( in vec3 from, in vec3[] pnts );

    mapsize_t size() const;

    final vec3 cellSize() const
    { return (matrix * vec4(1,1,1,0)).xyz; }
}

/+
class WorldMap : Node
{
    static struct Element
    {
        float val = 0;
        float prop = 0;
    }

    MapData!(3,Element) vals;
    mat4 mtr;

    this( ivec3 msize, mat4 transform )
    {
        mtr = transform;
        vals.resize( msize );
    }

    @property const
    {
        mat4 matrix() { return mtr; }
        const(Node) parent() { return null; }
    }

    void setPoints( in vec3 from, in vec3[] pnts )
    {
        auto mtrinv = mtr.inv;
        auto mfrom = mlt( mtrinv, from );
        foreach( op; pnts )
        {
            auto p = mlt( mtrinv, op );
            auto crd = ivec3(p);
            auto vv = p - mfrom;
            if( vals.has(crd) )
            {
                vals[crd].val = 1;
                vals[crd].prop = 1;
                foreach( i; 0 .. cast(size_t)(vv.len * 2) )
                {
                    auto v = mfrom + vv.e * i * 0.5;
                    if( vals.has(ivec3(v)) )
                    {
                        vals[ivec3(v)].val = 0;
                        vals[ivec3(v)].prop = 1;
                    }
                }
            }
        }
    }

    static vec3 mlt( in mat4 m, in vec3 v )
    {
        return vec3( m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2] + m[0][3],
                     m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2] + m[1][3],
                     m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] );
    }

    float minCellSize() const
    {
        auto mincell = (matrix * vec4(1,1,1,0)).xyz;
        auto minval = float.max;
        foreach( v; mincell.data )
            if( minval > v ) minval = v;
        return minval;
    }
}

version(unittest) { import des.util.testsuite; }

unittest
{
    auto m = mat4(1,2,3,4,
                  5,6,7,8,
                  9,10,11,12,
                  13,14,15,16);
    auto v = vec3(1,2,3);
    auto a = (m * vec4(v,1)).xyz;
    auto b = WorldMap.mlt( m, v );
    assert( eq(a,b) );
}
+/
