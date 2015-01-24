@testex 0 == 0
@testex -0  == 0
@testex 1  == 1
@testex -1  == -1
@testex 1 - 1  == 0
@testex 1 + 1  == 2
@ex Clear(a)
@testex a  == a
@testex 0 + a  == a
@testex a + 0  == a
@testex a - 0  == a
@testex 1 * a  == a
@testex 0 * a  == 0
@testex a * 1  == a
@testex a * 0  == 0
@testex a * -0  == 0
@testex -0 * a  == 0
# fixed bug
@testex a + a * a - a * a == a
# fixed bug for this one
@testex Apply(List, zb + za + 7 + 2 * x^r  + 2 + a + c + x^3 + x^2) ==  [9,2*a,x^2,x^3,2*x^r,za,zb]
@testex Apply(List, z^7 + 2 * z^6 + 5*z^3 + 10 *z  + 1) == [1,10*z,5*z^3,2*z^6,z^7]
@testex Apply(List, a * a + 1 / ((z + y) * (z + y)) ) == [a ^ 2,(y + z) ^ -2]
@testex Apply(List,a + z + 10*a^2 + 2 * z^2) == [a,10*a^2,z,2*z^2]
@testex (a+b)/(a+b) == 1
@testex (a + b)^2/(a+b) == a + b
@testex (a^2)^2 == a^4
@testex (a^t)^z == a^(t*z)