module model.mapdata;

import std.conv;
import std.algorithm;

/+
struct MapData(size_t N, T)
{
    T[] data;
    size_t[N] size;

    void resize( in size_t[N] szs... )
    {
        data.length = reduce!((r,a)=>r*=a)(szs.dup);
        size = szs;
    }

    void resize(X,string AS)( in Vector!(N,X,AS) sv )
        if( is(X : size_t) )
    { reisze( to!(size_t[N])(sv.data) ); }

    ref T opIndex( in size_t[N] i... )
    { return data[index(i)]; }

    ref const(T) opIndex( in size_t[N] i... ) const
    { return data[index(i)]; }

    ref T opIndex(X,string AS)( in size_t[N] i... )
        if( is(X : size_t) )
    { return data[index(i)]; }

    ref const(T) opIndex( in size_t[N] i... ) const
    { return data[index(i)]; }

protected:

    static size_t[N] convVec(X,string AS)( in Vector!(N,X,AS) v )
        if( is( X : size_t ) )
    { return to!(size_t[N])(v.data); }

    size_t index( in size_t[N] i... ) const
    {

    }
}
+/
