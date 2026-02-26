/**
 * Minimal stub for InferLocalVarTypes and RewriteForIn map-based test cases.
 * This intentionally mirrors as3commons Map API shape with untyped return values.
 */
package org.as3commons.collections {
    public class Map {
        private var _data:Object = {};

        public function Map() {
        }

        public function add(key:*, value:*):void {
            _data[key] = value;
        }

        public function itemFor(key:*):* {
            return _data[key];
        }
    }
}
