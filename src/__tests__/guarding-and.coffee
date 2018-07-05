{transformed} = require '../test_helper'

test 'generates soak from guarding and', ->
  transformed 'a.b && a.b.c', 'a.b?.c'
  transformed 'a.b && a.b[c].d', 'a.b?[c].d'
  transformed 'a && a.b.c', 'a?.b.c'
  transformed 'a && a(b)', 'a? b'
  transformed 'a[0].b && a[0].b(c).d', 'a[0].b?(c).d'

test "doesn't generate soak", ->
  transformed 'a.b && a.b', 'a.b and a.b'
  transformed 'a && c.a.b', 'a and c.a.b'
  transformed 'a.b && c.a.b', 'a.b and c.a.b'
  transformed 'a.b && c[a.b]', 'a.b and c[a.b]'
