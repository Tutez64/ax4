/**
 * Test case for Date API rewrites.
 * Covers:
 * - Instance setters/getters (setTime, setFullYear, setMonth, setDate, setHours, setMinutes, setSeconds, setMilliseconds).
 * - Milliseconds property get/set/assign ops.
 * - UTC helpers (getUTCMilliseconds, Date.UTC).
 * - The time (getTime, time, valueOf), read in whole milliseconds through ASCompat.
 */
package {
    public class TestFilterDateApi {
        public function TestFilterDateApi() {
            var date:Date = new Date(0);
            date.setTime(1234);
            date.setFullYear(2020, 0, 2);
            date.setMonth(5, 6);
            date.setDate(7);
            date.setHours(8, 9, 10, 11);
            date.setMinutes(12, 13, 14);
            date.setSeconds(15, 16);
            date.setMilliseconds(17);

            var ms:Number = date.getMilliseconds();
            var utcMs:Number = date.getUTCMilliseconds();

            date.milliseconds = 18;
            date.milliseconds += 2;
            var propMs:Number = date.milliseconds;

            var utc:Number = Date.UTC(2021, 1, 3, 4, 5, 6, 7);

            var time:Number = date.getTime();
            var propTime:Number = date.time;
            var value:Number = date.valueOf();
            var elapsed:Number = new Date().getTime() - time;
        }
    }
}
