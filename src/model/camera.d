module model.camera;

import std.math;

import des.math.linear;
import des.space;

///
struct UnitCameraParams
{
    float fov;  /// angle
    float near; ///
    float far;  ///

    uivec2 res;  /// resolution

    ///
    float maxResultDist( float cell ) const
    {
        auto maxAngleResolution = (fov / 180.0f * PI) / res.y;
        return abs( cell / tan(maxAngleResolution) );
    }
}

///
class UnitCamera : SimpleCamera
{
protected:
    ///
    UnitCameraParams params;

public:
    ///
    this( SpaceNode p, UnitCameraParams prms )
    {
        super(p);
        params = prms;
        fov = prms.fov;
        near = prms.near;
        far = prms.far;
    }

    const @property
    {
        ///
        uivec2 resolution() { return params.res; }
    }

    ///
    float maxResultDist( float cell ) const
    { return params.maxResultDist( cell ); }
}
