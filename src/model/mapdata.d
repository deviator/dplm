module model.mapdata;

import std.conv;
import std.algorithm;

import des.math.linear;

struct MapData(size_t N, T)
{
    T[] data;
    size_t[N] size;

pure:
    this( in size_t[N] szs... )
    { resize(szs); }

    this(V)( in V crd ) if( isCoord!V )
    { resize( crd ); }

    void resize( in size_t[N] szs... )
    {
        data.length = reduce!((r,a)=>r*=a)(szs.dup);
        size = szs;
    }

    void resize(V)( in V sv ) if( isCoord!V )
    { resize( convVec(sv) ); }

    ref T opIndex( in size_t[N] crd... )
    { return data[index(crd)]; }

    ref const(T) opIndex( in size_t[N] crd... ) const
    { return data[index(crd)]; }

    ref T opIndex(V)( in V crd )
        if( isCoord!V )
    { return data[index(convVec(crd))]; }

    ref const(T) opIndex(V)( in V crd ) const
        if( isCoord!V )
    { return data[index(convVec(crd))]; }

    static size_t[N] convVec(V)( in V v ) if( isCoord!V )
    { return to!(size_t[N])(v.data); }

    bool has( in size_t[N] crd... ) const
    {
        return crd[0] >= 0 && crd[0] < size[0] &&
               crd[1] >= 0 && crd[1] < size[1] &&
               crd[2] >= 0 && crd[2] < size[2];
    }

    bool has(V)( in V crd ) const
    if( isCoord!V )
    {
        return crd[0] >= 0 && crd[0] < size[0] &&
               crd[1] >= 0 && crd[1] < size[1] &&
               crd[2] >= 0 && crd[2] < size[2];
    }

    size_t index( in size_t[N] crd... ) const
    {
        size_t ret;
        foreach( i; 0 .. N )
        {
            auto v = reduce!((r,v)=>(r*=v))(1UL,size[0..i]);
            ret += crd[i] * v;
        }
        return ret;
    }

    static @property bool isCoord(V)()
    {
        static if( !isVector!V ) return false;
        else return is( V.datatype : size_t ) && V.dims == N;
    }
}

unittest
{
    import des.util.testsuite;

    auto m = MapData!(3,int)( 2,2,2 );
    m[0,0,0] = 10;
    m[ivec3(1,1,0)] = 3;

    assert( eq( m.data, [10,0,0,3,0,0,0,0] ) );
}
