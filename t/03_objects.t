use strict ;
use Test ;

use Inline Config => 
           DIRECTORY => './_Inline_test';

use Inline(
	Java => 'DATA'
) ;


BEGIN {
	plan(tests => 14) ;
}


my $o1 = new obj() ;
my $o2 = new obj() ;
ok($o1->get_data(), "data") ;
ok($o2->get_data(), "data") ;
ok($o1->get_this()->get_data(), "data") ;
ok($o1->get_that($o2)->get_data(), "data") ;

$o1->set_data("new data") ;
ok($o1->get_data(), "new data") ;
ok($o2->get_data(), "new data") ;

obj->set_data("new new data") ;
ok($o1->get_data(), "new new data") ;
ok($o2->get_data(), "new new data") ;

my $so1 = new sub_obj(5) ;
my $so2 = new sub_obj(6) ;
ok($so1->get_data(), "new new data") ;
ok($so1->get_number(), 5) ;
ok($so2->get_number(), 6) ;

$so1->set_number(7) ;
ok($so1->get_number(), 7) ;

my $io = new obj::inner_obj($o1) ;
ok($io->get_data(), "new new data") ;

my $al = $o1->new_arraylist() ;
$o1->set_arraylist($al, "array data") ;
ok($o1->get_arraylist($al), "array data") ;


__END__

__Java__

import java.util.* ;


class obj {
	public static String data = "data" ;

	public obj(){
	}

	public obj get_this(){
		return this ;
	}

	public obj get_that(obj o){
		return o ;
	}

	public static String get_data(){
		return data ;
	}

	public static void set_data(String d){
		data = d ;
	}
	
	public ArrayList new_arraylist(){
		return new ArrayList() ;
	}

	public void set_arraylist(ArrayList a, String s){
		a.add(0, s) ;
	}

	public String get_arraylist(ArrayList a){
		return (String)a.get(0) ;
	}

	
	class inner_obj {
		public inner_obj(){
		}

		public String get_data(){
			return obj.this.get_data() ;
		}
	}
}


class sub_obj extends obj {
	public int number ;

	public sub_obj(int num){
		super() ;
		number = num ;
	}

	public int get_number(){
		return number ;
	}

	public void set_number(int num){
		number = num ;
	}
}