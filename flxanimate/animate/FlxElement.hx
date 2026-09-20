package flxanimate.animate;

import flixel.math.FlxPoint;
import flxanimate.data.AnimationData;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;

class FlxElement 
{
    @:allow(flxanimate.animate.FlxKeyFrame)
    var _parent:FlxKeyFrame;
    /**
     * All the other parameters that are exclusive to the symbol (instance, type, symbol name, etc.)
     */
    public var symbol(default, null):SymbolParameters;
    /**
     * The name of the frame itself.
     */
    public var bitmap(default,null):String;
    /**
     * The matrix that the symbol or bitmap has.
     */
    public var matrix(default, null):FlxMatrix;
    /**
     * Creates a new `FlxElement` instance.
     * @param name the name of the element. `WARNING:` this name is dynamic, in other words, this name can used for the limb or the symbol!
     * @param symbol the symbol settings, ignore this if you want to add a limb.
     * @param matrix the matrix of the element.
     */
    public function new(?bitmap:String, ?symbol:SymbolParameters, ?matrix:FlxMatrix)
    {
        this.bitmap = bitmap;
        this.symbol = symbol;
        this.matrix = (matrix == null) ? new FlxMatrix() : matrix;
    }

    public function toString()
    {
        return '{matrix: $matrix, bitmap: $bitmap}';
    }
    public function destroy()
    {
        _parent = null;
        if (symbol != null)
            symbol.destroy();
        bitmap = null;
        matrix = null;
    }
    public static function fromJSON(element:Element)
    {
        var isSymbol = element.SI != null;
        var params:SymbolParameters = null;
        if (isSymbol)
        {      
            params = new SymbolParameters();
            params.instance = element.SI.IN;
            params.type = switch (element.SI.ST)
            {
                case movieclip, "movieclip": MovieClip;
                case button, "button": Button;
                default: Graphic;
            }
            var lp:LoopType = (element.SI.LP == null) ? loop : element.SI.LP.split("R")[0];
            params.loop = switch (lp) // remove the reverse sufix
            {
                case playonce, "playonce": PlayOnce;
                case singleframe, "singleframe": SingleFrame;
                default: Loop;
            }
            params.reverse = (element.SI.LP == null) ? false : StringTools.contains(element.SI.LP, "R");
            params.firstFrame = element.SI.FF;
            params.colorEffect = AnimationData.fromColorJson(element.SI.C);
            params.name = element.SI.SN;
            params.transformationPoint = FlxPoint.weak(element.SI.TRP.x, element.SI.TRP.y);
        }

        // ПАТЧ: этот атлас использует плоское поле "MX" (6 чисел: a,b,c,d,tx,ty)
        // вместо ожидаемого библиотекой "M3D" (16-элементная 3D-матрица).
        // Поддерживаем оба формата — сначала пробуем MX, и только если его нет, идём по старому пути с M3D.
        var mxRaw = (isSymbol) ? Reflect.field(element.SI, "MX") : Reflect.field(element.ASI, "MX");
        var m3d = (isSymbol) ? element.SI.M3D : element.ASI.M3D;

        var m:Array<Float>;
        if (mxRaw != null)
        {
            m = [for (i in 0...14) 0.0];
            m[0] = mxRaw[0];
            m[1] = mxRaw[1];
            m[4] = mxRaw[2];
            m[5] = mxRaw[3];
            m[12] = mxRaw[4];
            m[13] = mxRaw[5];
        }
        else
        {
            var array = Reflect.fields(m3d);
            if (!Std.isOfType(m3d, Array))
                array.sort((a, b) -> Std.parseInt(a.substring(1)) - Std.parseInt(b.substring(1)));
            m = (m3d is Array) ? m3d : [for (field in array) Reflect.field(m3d, field)];

            if (!isSymbol && m3d == null)
            {
                m[0] = m[5] = 1;
                m[1] = m[4] = m[12] = m[13] = 0;
            }
        }

        var pos = (isSymbol) ? element.SI.bitmap.POS : element.ASI.POS;
        if (pos == null)
            pos = {x: 0, y: 0};
        return new FlxElement((isSymbol) ? element.SI.bitmap.N : element.ASI.N, params, new FlxMatrix(m[0], m[1], m[4], m[5], m[12] + pos.x, m[13] + pos.y));
    }
}
