/**
 * Test case: Handling name conflicts between static and instance fields.
 * Verifies that the converter renames instance fields (or static fields)
 * to avoid Haxe compilation errors "Same field name can't be used for both static and instance".
 *
 * Case 1: Same class conflict (Invalid AS3 but possible in relaxed mode).
 * Case 2: Inheritance conflict (Subclass static vs Superclass instance).
 * Case 3: Conflict with extern (Object.toString).
 * Case 4: Singleton pattern (Static wrapper around instance method).
 * Case 5: The `_name` rename is taken (Starling: static and instance `get juggler()`, and a `_juggler` var),
 *         so the instance field becomes `name_instance` instead of a duplicate.
 */
package {
	public class TestFilterHandleStaticInstanceConflict extends Base {
		// Case 1: Same class conflict
		public static var conflictVar:int = 10;
		public var conflictVar:int = 20;

		public static function conflictFunc():void {
            conflictVar = 50; // static access
        }
		public function conflictFunc():void {
            conflictVar = 60; // instance access
        }

		// Case 2: Inheritance conflict (extends Base)
		// Base has instance 'inheritedConflict'. This class has static 'inheritedConflict'.
		public static function inheritedConflict():void {} 

		public function test():void {
            // Case 1: Same class conflict
			this.conflictVar = 30; // Refers to instance (explicit this) -> should be renamed
			TestFilterHandleStaticInstanceConflict.conflictVar = 40; // Refers to static -> should NOT be renamed
            
            this.conflictFunc(); // Refers to instance -> should be renamed
            TestFilterHandleStaticInstanceConflict.conflictFunc(); // Refers to static -> should NOT be renamed
            
            // Case 2: Inheritance
            this.inheritedConflict(); // instance -> should be renamed
            TestFilterHandleStaticInstanceConflict.inheritedConflict(); // static -> should NOT be renamed
		}
	}
}

class Base {
	public function inheritedConflict():void {}
}

// Case 3: Extern conflict (Object.toString is instance)
class ExternConflict {
	public static function toString():String { return "static"; }
    
    public function test():void {
        this.toString();
        ExternConflict.toString();
    }
}

// Case 4: Singleton Pattern (Facebook style)
class SingletonBase {
    public function api():void {}
}

class Singleton extends SingletonBase {
    private static var _instance:Singleton = new Singleton();
    public static function get instance():Singleton { return _instance; }
    
    // Conflict: static api vs inherited instance api
    public static function api():void {
        instance.api(); // Should be renamed to instance._api()
    }
}

// Case 5: `_juggler` is already a field (Starling.juggler / Starling.current.juggler)
class TakenRename {
    private static var sCurrent:TakenRename;
    private var _juggler:Object = {};

    public static function get juggler():Object { return sCurrent ? sCurrent._juggler : null; }
    public function get juggler():Object { return _juggler; }

    public function test():Object {
        return this.juggler;
    }
}
