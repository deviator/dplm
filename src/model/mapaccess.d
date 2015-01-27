module model.mapaccess;

public import des.il;
public import des.math.linear;

///
struct MapElement
{
    ///
    uint meas = 0;
    ///
    float ts = 0;
    ///
    vec2 val;
}

///
struct MapRegion
{
    ///
    fRegion3 reg;
    ///
    Image3 img;

    ///
    vec3 toWorld( ivec3 crd ) const pure
    { return vec3( reg.pos + reg.size * vec3(crd) / vec3(img.size) ); }

    ///
    vec3 toWorld( size_t ind ) const pure
    { return toWorld( ivec3( getCoord( img.size, ind ) ) ); }
}

///
interface MapAccess
{
    ///
    MapRegion getRegion( in fRegion3 );
}
