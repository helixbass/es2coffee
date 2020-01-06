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

test 'multiple guards', ->
  transformed 'a.b && a.b.c && a.b.c.d', 'a.b?.c?.d'
  transformed 'a.b && a.b.c && a.b.c()', 'a.b?.c?()'

test 'if guarding body', ->
  transformed(
    '''
      if (a) {
        a.b()
      }
    '''
    '''
      a?.b()
    '''
  )

  transformed(
    '''
      if (a && a.b) {
        a.b.c()
      }
    '''
    '''
      a?.b?.c()
    '''
  )

test 'inverts and generates soak from guarding or', ->
  transformed '!a.b || !a.b.c', 'not a.b?.c'
  transformed '!a.b || !a.b[c].d', 'not a.b?[c].d'
  transformed '!a || !a.b.c', 'not a?.b.c'
  transformed '!a || !a(b)', 'not a? b'
  transformed '!a[0].b || !a[0].b(c).d', 'not a[0].b?(c).d'

test 'multiple guarding ors', ->
  transformed '!a.b || !a.b.c || !a.b.c.d', 'not a.b?.c?.d'
  transformed '!a.b || !a.b.c || !a.b.c()', 'not a.b?.c?()'

test 'generates soak from guarding and + in', ->
  transformed(
    "a && (a.type === 'HTMLText' || a.type === 'HTMLRCDataText')"
    "a?.type in ['HTMLText', 'HTMLRCDataText']"
  )

test 'generates soak from guarding existence and + in', ->
  transformed(
    "a != null && (a.type === 'HTMLText' || a.type === 'HTMLRCDataText')"
    "a?.type in ['HTMLText', 'HTMLRCDataText']"
  )

test 'generates soak from double guarding existence', ->
  transformed 'a != null && a.b != null', 'a?.b?'
