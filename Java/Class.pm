package Inline::Java::Class ;


use strict ;

$Inline::Java::Class::VERSION = '0.10' ;

use Carp ;


my $INT_RE = '^[+-]?\d+$' ;
my $FLOAT_RE = '^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$' ;

my $RANGE = {
	'java.lang.Byte' => {
		REGEXP => $INT_RE,
		MAX => 127,
		MIN => -128,
	},
	'java.lang.Short' => {
		REGEXP => $INT_RE,
		MAX => 32767,
		MIN => -32768,
	},
	'java.lang.Integer' => {
		REGEXP => $INT_RE,
		MAX => 2147483647,
		MIN => -2147483648,
	},
	'java.lang.Long' => {
		REGEXP => $INT_RE,
		MAX => 2147483647,
		MIN => -2147483648,
		# MAX => 9223372036854775807,
		# MIN => -9223372036854775808,
	},
	'java.lang.Float' => {
		REGEXP => $FLOAT_RE,
		MAX => 3.4028235e38,
		MIN => -3.4028235e38,
		POS_MIN	=> 1.4e-45,
		NEG_MAX => -1.4e-45,
	},
	'java.lang.Double' => {
		REGEXP => $FLOAT_RE,
		MAX => 3.4028235e38,
		MIN => -3.4028235e38,
		# MAX => 1.7976931348623157e308,
		# MIN => -1.7976931348623157e308,
		POS_MIN => 4.9e-324,
		NEG_MAX => -4.9e-324,
	},
} ;
$RANGE->{byte} = $RANGE->{'java.lang.Byte'} ;
$RANGE->{short} = $RANGE->{'java.lang.Short'} ;
$RANGE->{int} = $RANGE->{'java.lang.Integer'} ;
$RANGE->{long} = $RANGE->{'java.lang.Long'} ;
$RANGE->{float} = $RANGE->{'java.lang.Float'} ;
$RANGE->{double} = $RANGE->{'java.lang.Double'} ;



# This method makes sure that the class we are asking for
# has the correct form for a Java class.
sub ValidateClass {
	my $class = shift ;

 	my $ret = ValidateClassSplit($class) ;
	
	return $ret ;
}


sub ValidateClassSplit {
	my $class = shift ;

	my $cre = '([\w$]+)(((\.([\w$]+))+)?)' ;
	if (($class =~ /^($cre)()()()$/)||
		($class =~ /^(\[+)([BCDFIJSZ])()()$/)||
		($class =~ /^(\[+)([L])($cre)(;)$/)){
		return (wantarray ? ($1, $2, $3, $4) : $class) ;
	}

	croak "Invalid Java class name $class" ;
}


sub CastArguments {
	my $args = shift ;
	my $proto = shift ;
	my $module = shift ;

	Inline::Java::debug_obj($args) ;
	Inline::Java::debug_obj($proto) ;

	if (scalar(@{$args}) != scalar(@{$proto})){
		croak "Wrong number of arguments" ;
	}

	my $ret = [] ;
	my $score = 0 ;
	for (my $i = 0 ; $i < scalar(@{$args}) ; $i++){
		my @r = CastArgument($args->[$i], $proto->[$i], $module) ;
		$ret->[$i] = $r[0] ;
		$score += $r[1] ;
	}

	return ($ret, $score) ;
}


sub CastArgument {
	my $arg = shift ;
	my $proto = shift ;
	my $module = shift ;

	ValidateClass($proto) ;

	if ((ClassIsReference($proto))&&(! UNIVERSAL::isa($arg, "Inline::Java::Object"))){
		# Here we allow scalars to be passed in place of java.lang.Object
		# They will wrapped on the Java side.
		if (defined($arg)){
			if (UNIVERSAL::isa($arg, "ARRAY")){
				if (! UNIVERSAL::isa($arg, "Inline::Java::Array")){
					my $an = new Inline::Java::Array::Normalizer($proto, $arg) ;
					my $flat = $an->FlattenArray() ; 
					my $inline = Inline::Java::get_INLINE($module) ;
					my $obj = Inline::Java::Object->__new($proto, $inline, -1, $flat->[0], $flat->[1]) ;

					# We need to create the array on the Java side, and then grab 
					# the returned object.
					$arg = new Inline::Java::Array($obj) ;
				}
				else{
					Inline::Java::debug("argument is already an Inline::Java array") ;
				}
			}
			else{
				if (ref($arg)){
					# We got some other type of ref...
					croak "Can't convert $arg to object $proto" ;
				}
				else{
					# Here we got a scalar
					# Here we allow scalars to be passed in place of java.lang.Object
					# They will wrapped on the Java side.
					if ($proto ne "java.lang.Object"){
						croak "Can't convert $arg to object $proto" ;
					}
				}
			}
		}
	}
	if ((ClassIsPrimitive($proto))&&(ref($arg))){
		croak "Can't convert $arg to primitive $proto" ;
	}

	if (ClassIsNumeric($proto)){
		if (! defined($arg)){
			return (0, 0) ;
		}
		my $re = $RANGE->{$proto}->{REGEXP} ;
		my $min = $RANGE->{$proto}->{MIN} ;
		my $max = $RANGE->{$proto}->{MAX} ;
		Inline::Java::debug("min = $min, max = $max, val = $arg") ;
		if ($arg =~ /$re/){
			if (($arg >= $min)&&($arg <= $max)){
				return ($arg, 0) ;
			}
			croak "$arg out of range for type $proto" ;
		}
		croak "Can't convert $arg to $proto" ;
	}
	elsif (ClassIsChar($proto)){
		if (! defined($arg)){
			return ("\0", 0) ;
		}
		if (length($arg) == 1){
			return ($arg, 0) ;
		}
		croak "Can't convert $arg to $proto" ;
	}
	elsif (ClassIsBool($proto)){
		if ((! defined($arg))||(! $arg)){
			return (0, 0) ;
		}
		else{
			return (1, 0) ;
		}
	}
	elsif (ClassIsString($proto)){
		if (! defined($arg)){
			return (undef, 0) ;
		}
		return ($arg, 0) ;
	}
	else{
		if (! defined($arg)){
			return ($arg, 0) ;
		}
		# Here the prototype calls for an object of type $proto
		# We must ask Java if our object extends $proto		
		if (ref($arg)){
			my $msg = $arg->__isa($proto) ;
			if ($msg){
				croak $msg ;
			}
			Inline::Java::debug("$arg is a $proto") ;
		}

		return ($arg, 0) ;
	}
}


sub ClassIsNumeric {
	my $class = shift ;

	my @list = qw(
		java.lang.Byte
		java.lang.Short
		java.lang.Integer
		java.lang.Long
		java.lang.Float
		java.lang.Double
		byte
		short
		int
		long
		float
		double
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsString {
	my $class = shift ;

	my @list = qw(
		java.lang.String
		java.lang.StringBuffer
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsChar {
	my $class = shift ;

	my @list = qw(
		java.lang.Character
		char
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsBool {
	my $class = shift ;

	my @list = qw(
		java.lang.Boolean
		boolean
	) ;

	foreach my $l (@list){
		if ($class eq $l){
			return 1 ;
		}
	}

	return 0 ;
}


sub ClassIsPrimitive {
	my $class = shift ;

	if ((ClassIsNumeric($class))||(ClassIsString($class))||(ClassIsChar($class))||(ClassIsBool($class))){
		return 1 ;
	}

	return 0 ;
}


sub ClassIsReference {
	my $class = shift ;

	if (ClassIsPrimitive($class)){
		return 0 ;
	}

	return 1 ;
}


sub ClassIsArray {
	my $class = shift ;

	if ((ClassIsReference($class))&&($class =~ /^(\[+)(.*)$/)){
		return 1 ;
	}

	return 0 ;
}


1 ;



__DATA__

class InlineJavaClass {
	InlineJavaServer ijs ;
	InlineJavaProtocol ijp ;
	HashMap hm = new HashMap() ;

	InlineJavaClass(InlineJavaServer _ijs, InlineJavaProtocol _ijp){
		ijs = _ijs ;
		ijp = _ijp ;

		hm.put("B", "byte") ;
		hm.put("S", "short") ;
		hm.put("I", "int") ;
		hm.put("J", "long") ;
		hm.put("F", "float") ;
		hm.put("D", "double") ;
		hm.put("C", "char") ;
		hm.put("Z", "boolean") ;
	}


	/*
		Makes sure a class exists
	*/
	Class ValidateClass(String name) throws InlineJavaException {
		String s = (String)hm.get(name) ;
		if (s != null){
			name = s ;
		}

		try {
			Class c = Class.forName(name) ;
			return c ;
		}
		catch (ClassNotFoundException e){
			throw new InlineJavaException("Class " + name + " not found") ;
		}
	}

	/*
		This is the monster method that determines how to cast arguments
	*/
	Object [] CastArguments (Class [] params, ArrayList args) throws InlineJavaException {
		Object ret[] = new Object [params.length] ;
	
		for (int i = 0 ; i < params.length ; i++){	
			// Here the args are all strings or objects (or undef)
			// we need to match them to the prototype.
			Class p = params[i] ;
			ijs.debug("    arg " + String.valueOf(i) + " of signature is " + p.getName()) ;

			ret[i] = CastArgument(p, (String)args.get(i)) ;
		}

		return ret ;
	}


	/*
		This is the monster method that determines how to cast arguments
	*/
	Object CastArgument (Class p, String argument) throws InlineJavaException {
		Object ret = null ;
	
		ArrayList tokens = new ArrayList() ;
		StringTokenizer st = new StringTokenizer(argument, ":") ;
		for (int j = 0 ; st.hasMoreTokens() ; j++){
			tokens.add(j, st.nextToken()) ;
		}
		if (tokens.size() == 1){
			tokens.add(1, "") ;
		}
		String type = (String)tokens.get(0) ;
		
		// We need to separate the primitive types from the 
		// reference types.
		boolean num = ClassIsNumeric(p) ;
		if ((num)||(ClassIsString(p))){
			if (type.equals("undef")){
				if (num){
					ijs.debug("  args is undef -> forcing to " + p.getName() + " 0") ;
					ret = ijp.CreateObject(p, new Object [] {"0"}, new Class [] {String.class}) ;
					ijs.debug("    result is " + ret.toString()) ;
				}
				else{
					ret = null ;
					ijs.debug("  args is undef -> forcing to " + p.getName() + " " + ret) ;
					ijs.debug("    result is " + ret) ;
					// ijp.CreateObject(p, new Object [] {""}, new Class [] {String.class}) ;
				}
			}
			else if (type.equals("scalar")){
				String arg = ijp.pack((String)tokens.get(1)) ;
				ijs.debug("  args is scalar -> forcing to " + p.getName()) ;
				try	{							
					ret = ijp.CreateObject(p, new Object [] {arg}, new Class [] {String.class}) ;
					ijs.debug("    result is " + ret.toString()) ;
				}
				catch (NumberFormatException e){
					throw new InlineJavaCastException("Can't convert " + arg + " to " + p.getName()) ;
				}
			}
			else{
				throw new InlineJavaCastException("Can't convert reference to " + p.getName()) ;
			}
		}
		else if (ClassIsBool(p)){
			if (type.equals("undef")){
				ijs.debug("  args is undef -> forcing to bool false") ;
				ret = new Boolean("false") ;
				ijs.debug("    result is " + ret.toString()) ;
			}
			else if (type.equals("scalar")){
				String arg = ijp.pack(((String)tokens.get(1)).toLowerCase()) ;
				ijs.debug("  args is scalar -> forcing to bool") ;
				if ((arg.equals(""))||(arg.equals("0"))){
					arg = "false" ;
				}
				else{
					arg = "true" ;
				}
				ret = new Boolean(arg) ;
				ijs.debug("    result is " + ret.toString()) ;
			}
			else{
				throw new InlineJavaCastException("Can't convert reference to " + p.getName()) ;
			}
		}
		else if (ClassIsChar(p)){
			if (type.equals("undef")){
				ijs.debug("  args is undef -> forcing to char '\0'") ;
				ret = new Character('\0') ;
				ijs.debug("    result is " + ret.toString()) ;
			}
			else if (type.equals("scalar")){
				String arg = ijp.pack((String)tokens.get(1)) ;
				ijs.debug("  args is scalar -> forcing to char") ;
				char c = '\0' ;
				if (arg.length() == 1){
					c = arg.toCharArray()[0] ;
				}
				else if (arg.length() > 1){
					throw new InlineJavaCastException("Can't convert " + arg + " to " + p.getName()) ;
				}
				ret = new Character(c) ;
				ijs.debug("    result is " + ret.toString()) ;
			}
			else{
				throw new InlineJavaCastException("Can't convert reference to " + p.getName()) ;
			}
		}
		else {
			ijs.debug("  class " + p.getName() + " is reference") ;
			// We know that what we expect here is a real object
			if (type.equals("undef")){
				ijs.debug("  args is undef -> forcing to null") ;
				ret = null ;
			}
			else if (type.equals("scalar")){
				// Here if we need a java.lang.Object.class, it's probably
				// because we can store anything, so we use a String object.
				if (p == java.lang.Object.class){
					String arg = ijp.pack((String)tokens.get(1)) ;
					ret = arg ;
				}
				else{
					throw new InlineJavaCastException("Can't convert primitive type to " + p.getName()) ;
				}
			}
			else{
				// We need an object and we got an object...
				ijs.debug("  class " + p.getName() + " is reference") ;

				String c_name = (String)tokens.get(1) ;
				String objid = (String)tokens.get(2) ;

				Class c = ValidateClass(c_name) ;

				if (DoesExtend(c, p)){
					ijs.debug("    " + c.getName() + " is a kind of " + p.getName()) ;
					// get the object from the hash table
					Integer oid = new Integer(objid) ;
					Object o = ijs.objects.get(oid) ;
					if (o == null){
						throw new InlineJavaException("Object " + oid.toString() + " of type " + c_name + " is not in object table ") ;
					}
					ret = o ;
				}
				else{
					throw new InlineJavaCastException("Can't cast a " + c.getName() + " to a " + p.getName()) ;
				}
			}
		}

		return ret ;
	}


	boolean DoesExtend(Class a, Class b){
		// We need to check if a extends b
		Class parent = a ;
		boolean got_it = false ;
		while (parent != null){
			ijs.debug("    parent is " + parent.getName()) ;
			if (parent == b){
				got_it = true ;
				break ;
			}
			parent = parent.getSuperclass() ;
		}

		return got_it ;
	}


	/*
		Finds the wrapper class for the passed primitive type.
	*/
	Class FindWrapper (Class p){
		Class [] list = {
			byte.class,
			short.class,
			int.class,
			long.class,
			float.class,
			double.class,
			boolean.class,
			char.class,
		} ;
		Class [] listw = {
			java.lang.Byte.class,
			java.lang.Short.class,
			java.lang.Integer.class,
			java.lang.Long.class,
			java.lang.Float.class,
			java.lang.Double.class,
			java.lang.Boolean.class,
			java.lang.Character.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			if (p == list[i]){
				return listw[i] ;
			}
		}

		return p ;
	}


	boolean ClassIsPrimitive (Class p){
		String name = p.getName() ;

		if ((ClassIsNumeric(p))||(ClassIsString(p))||(ClassIsChar(p))||(ClassIsBool(p))){
			return true ;
		}

		ijs.debug("  class " + name + " is reference") ;
		return false ;
	}


	/*
		Determines if class is of numerical type.
	*/
	boolean ClassIsNumeric (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.Byte.class,
			java.lang.Short.class,
			java.lang.Integer.class,
			java.lang.Long.class,
			java.lang.Float.class,
			java.lang.Double.class,
			byte.class,
			short.class,
			int.class,
			long.class,
			float.class,
			double.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive numeric") ;
				return true ;
			}
		}

		return false ;
	}


	/*
		Class is String or StringBuffer
	*/
	boolean ClassIsString (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.String.class,
			java.lang.StringBuffer.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive string") ;
				return true ;
			}
		}

		return false ;
	}


	/*
		Class is Char
	*/
	boolean ClassIsChar (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.Character.class,
			char.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive char") ;
				return true ;
			}
		}

		return false ;
	}


	/*
		Class is Bool
	*/
	boolean ClassIsBool (Class p){
		String name = p.getName() ;

		Class [] list = {
			java.lang.Boolean.class,
			boolean.class,
		} ;

		for (int i = 0 ; i < list.length ; i++){
			if (p == list[i]){
				ijs.debug("  class " + name + " is primitive bool") ;
				return true ;
			}
		}

		return false ;
	}

	
	/*
		Determines if a class is not of a primitive type or of a 
		wrapper class.
	*/
	boolean ClassIsReference (Class p){
		String name = p.getName() ;

		if (ClassIsPrimitive(p)){
			return false ;
		}

		ijs.debug("  class " + name + " is reference") ;

		return true ;
	}

	boolean ClassIsArray (Class p){
		String name = p.getName() ;

		if ((ClassIsReference(p))&&(name.startsWith("["))){
			ijs.debug("  class " + name + " is array") ;
			return true ;
		}

		return false ;
	}

}

