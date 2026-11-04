package pipeline
{
   public class Checks
   {
      
      public function Checks()
      {
      }
      
      public static function run() : Array
      {
         var out:Array = [];
         var store:Store = new Store();
         store.add("b",2);
         store.add("a",1);
         store.add("c",3);
         var empty:Circle = Circle(Type.createEmptyInstance(Circle));
         out.push("empty=" + (empty.name == null ? "unset" : "set"));
         out.push("area=" + int(Math.round(new Circle(2).area() * 100)));
         out.push("kinds=" + Tools.kindName(Kind.Small) + "," + Tools.kindName(Kind.Big(3)) + "," + Std.string(Kind.Big(4)));
         out.push("names=" + store.nameOf(1) + "," + store.nameOf(9));
         out.push("imap=" + store.sumMap(store.byName));
         out.push("scale=" + Tools.scale(3) + "," + Tools.scale(3,5));
         out.push("radius=" + Tools.radiusOf(new Circle(7)));
         out.push("parse=" + Tools.safeParse("x") + "," + Tools.safeParse(""));
         out.push("count=" + Tools.count(4));
         out.push("emoji=" + Tools.emoji());
         out.push("nan=" + Std.string(Boolean(Math.isNaN(Number(Math.NaN)))) + "," + Std.string(Number(Math.POSITIVE_INFINITY) > 0));
         var one:Store = new Store();
         one.add("only",5);
         out.push("smap=" + store.idOf("b") + "," + store.idOf("z") + "," + one.firstName());
         var c:Circle = new Circle(1);
         store.tag(c,"unit");
         out.push("omap=" + store.tagOf(c) + "," + store.tagOf(new Circle(1)));
         var shape:Shape = new Circle(2);
         var assigned:int = shape.set_size(4);
         out.push("props=" + shape.get_size() + "," + assigned + "," + shape.get_label() + "," + new Shape("s").get_label());
         store.add("constructor",10);
         out.push("loops=" + store.total() + "," + store.joinedNames());
         out.push("typeof=" + Std.string(Tools.isFunction(Tools.emoji)) + "," + Std.string(Tools.isFunction(3)));
         store.reset();
         out.push("reset=" + store.idOf("a") + "," + store.nameOf(1));
         return out;
      }
   }
}

