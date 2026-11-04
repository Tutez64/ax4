/**
 * MathApi: Math.min/max with more than two values nest two-value calls; Math.round/floor/ceil
 * stay Math's (Int) where an int is expected and become fround/ffloor/fceil otherwise, with their
 * arguments rewritten too (a Math.max of several values inside Math.ceil into an int);
 * Infinity and -Infinity are Math's.
 */
package {
    public class TestFilterMathApi {
        public function bounds(a:Number, b:Number, c:Number, d:Number):int {
            var widest:Number = Math.max(a, b, c);
            var total:int = 0;
            total += Math.ceil(Math.max(-a, -b, c - d, d, widest));
            var rounded:Number = Math.round(Math.min(a, b, c));
            var none:Number = a > 0 ? Infinity : -Infinity;
            return total + int(rounded + none);
        }
    }
}
