require 'fy'
module = @

type_validate = (t)->
  if !t
    throw new Error "Type validation error. type is missing"
  switch t.main
    when 'int', 'float', 'string'
      if t.nest_list.length != 0
        throw new Error "Type validation error. #{t.main} can't have nest_list"
      if 0 != h_count t.field_hash
        throw new Error "Type validation error. #{t.main} can't have field_hash"
    when 'array'
      if t.nest_list.length != 1
        throw new Error "Type validation error. #{t.main} must have nest_list 1"
      if 0 != h_count t.field_hash
        throw new Error "Type validation error. #{t.main} can't have field_hash"
    when 'hash'
      if t.nest_list.length != 1
        throw new Error "Type validation error. #{t.main} must have nest_list 1"
      if 0 != h_count t.field_hash
        throw new Error "Type validation error. #{t.main} must have no field_hash"
    when 'struct'
      if t.nest_list.length != 0
        throw new Error "Type validation error. #{t.main} must have nest_list 0"
      if 0 == h_count t.field_hash
        throw new Error "Type validation error. #{t.main} must have field_hash"
      # TODO defined types ...
    else
      throw new Error "unknown type '#{t}'"
  for v in t.nest_list
    type_validate v
  
  for k,v of t.field_hash
    type_validate v
  
  return

class @Validation_context
  parent : null
  type_hash : {}
  var_hash  : {}
  constructor:()->
    @type_hash = {}
    @var_hash  = {}
  
  mk_nest : ()->
    ret = new module.Validation_context
    ret.parent = @
    ret

# ###################################################################################################
#    expr
# ###################################################################################################
# TODO array init
# TODO hash init
# TODO interpolated string init
class @This
  type : null
  validate : (ctx = new module.Validation_context)->
    type_validate @type
    return

class @Const
  val  : ''
  type : null
  validate : (ctx = new module.Validation_context)->
    type_validate @type
    switch @type.main
      when 'int'
        if parseInt(@val).toString() != @val
          throw new Error "Const validation error. '#{@val}' can't be int"
      when 'float'
        if parseFloat(@val).toString() != @val
          throw new Error "Const validation error. '#{@val}' can't be int"
      when 'string'
        'nothing'
        # string will be quoted and escaped
      # when 'char'
      
      else
        throw new Error "can't implement constant type '#{@type}'"
    
    return

class @Array_init
  list : []
  type : null
  constructor:()->
    @list = []
  
  validate : (ctx = new module.Validation_context)->
    type_validate @type
    if @type.main != 'array'
      throw new Error "Array_init validation error. type must be array but '#{@type}' occured"
    
    cmp_type = @type.nest_list[0]
    
    for v,k in @list
      v.validate(ctx)
      if !v.type.cmp cmp_type
        throw new Error "Array_init validation error. key '#{k}' must be type '#{cmp_type}' but '#{v.type}' found"
    
    return

class @Hash_init
  hash : {}
  type : null
  constructor:()->
    @hash = {}
  
  validate : (ctx = new module.Validation_context)->
    type_validate @type
    if @type.main != 'hash'
      throw new Error "Hash_init validation error. type must be hash but '#{@type}' occured"
    
    for k,v of @hash
      v.validate(ctx)
    
    cmp_type = @type.nest_list[0]
    for k,v of @hash
      if !v.type.cmp cmp_type
        throw new Error "Hash_init validation error. key '#{k}' must be type '#{cmp_type}' but '#{v.type}' found"
  
    return

class @Struct_init
  hash : {}
  type : null
  constructor:()->
    @hash = {}
  
  validate : (ctx = new module.Validation_context)->
    type_validate @type
    if @type.main != 'struct'
      throw new Error "Struct_init validation error. type must be struct but '#{@type}' occured"
      
    for k,v of @hash
      v.validate(ctx)
      if !v.type.cmp cmp_type = @type.field_hash[k]
        throw new Error "Struct_init validation error. key '#{k}' must be type '#{cmp_type}' but '#{v.type}' found"
    
    return

class @Var
  name : ''
  type : null
  validate : (ctx = new module.Validation_context)->
    if /^[_a-z][_a-z0-9]*$/i.test @name
      throw new Error "Var validation error. invalid identifier"
    type_validate @type
    return

@allowed_bin_op_hash =
  ADD : true
  SUB : true
  MUL : true
  DIV : true
  MOD : true
  POW : true
  
  BIT_AND : true
  BIT_OR  : true
  BIT_XOR : true
  
  BOOL_AND : true
  BOOL_OR  : true
  BOOL_XOR : true
  
  SHR : true
  SHL : true
  LSR : true # логический сдвиг вправо >>>
  
  ASSIGN : true
  ASS_ADD : true
  ASS_SUB : true
  ASS_MUL : true
  ASS_DIV : true
  ASS_MOD : true
  ASS_POW : true
  
  ASS_SHR : true
  ASS_SHL : true
  ASS_LSR : true # логический сдвиг вправо >>>
  
  ASS_BIT_AND : true
  ASS_BIT_OR  : true
  ASS_BIT_XOR : true
  
  ASS_BOOL_AND : true
  ASS_BOOL_OR  : true
  ASS_BOOL_XOR : true
  
  CMP : true

@assign_bin_op_hash = 
  ASSIGN : true
  ASS_ADD : true
  ASS_SUB : true
  ASS_MUL : true
  ASS_DIV : true
  ASS_MOD : true
  ASS_POW : true
  
  ASS_SHR : true
  ASS_SHL : true
  ASS_LSR : true # логический сдвиг вправо >>>
  
  ASS_BIT_AND : true
  ASS_BIT_OR  : true
  ASS_BIT_XOR : true
  
  ASS_BOOL_AND : true
  ASS_BOOL_OR  : true
  ASS_BOOL_XOR : true

class @Bin_op
  a : null
  b : null
  op: null
  type : null
  validate : (ctx = new module.Validation_context)->
    if !@a
      throw new Error "Bin_op validation error. a missing"
    @a.validate(ctx)
    if !@b
      throw new Error "Bin_op validation error. b missing"
    @b.validate(ctx)
    
    # TODO op in list of translateable bin_op
    
    type_validate @type
    return

@allowed_un_op_hash =
  INC_RET : true
  RET_INC : true
  DEC_RET : true
  RET_DEC : true
  BOOL_NOT: true
  BIT_NOT : true
  MINUS   : true
  PLUS    : true # parseFloat
  # new ?
  # delete ?

class @Un_op
  a   : null
  op  : null
  type: null
  validate : (ctx = new module.Validation_context)->
    if !@a
      throw new Error "Un_op validation error. a missing"
    @a.validate(ctx)
    
    # TODO op in list of translateable un_op
    
    type_validate @type
    return

class @Fn_call
  fn        : null
  arg_list  : []
  splat_fin : false
  type      : null
  constructor:()->
    @arg_list = []
  
  validate : (ctx = new module.Validation_context)->
    if !@fn
      throw new Error "Fn_call validation error. fn missing"
    @fn.validate(ctx)
    for arg in @arg_list
      arg.validate(ctx)
    
    type_validate @type
    return

# ###################################################################################################
#    stmt
# ###################################################################################################
# TODO var_decl check
class @Scope
  stmt_list : []
  constructor:()->
    @stmt_list = []
  
  validate : (ctx = new module.Validation_context)->
    ctx_nest = ctx.mk_nest()
    for stmt in @stmt_list
      stmt.validate(ctx_nest)
      # на самом деле валидными есть только Fn_call и assign, но мы об этом умолчим
    return

class @If
  cond: null
  t   : null
  f   : null
  constructor:()->
    @t = new module.Scope
    @f = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    if !@cond
      throw new Error "If validation error. cond missing"
    
    @cond.validate(ctx)
    @t.validate(ctx)
    @f.validate(ctx)
    return

# есть следующие валидные случаи компилирования switch
# 1. cont типа int. Тогда все hash key трактуются как int. (Но нельзя NaN и Infinity)
# 2. cont типа float.
# 3. cont типа string.
# 4. cont типа char.

class @Switch
  cond : null
  hash : {}
  f    : null # scope
  constructor:()->
    @hash = {}
    @f = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    if !@cond
      throw new Error "Switch validation error. cond missing"
    @cond.validate(ctx)
    
    if 0 == h_count @hash
      throw new Error "Switch validation error. no"
    switch @cond.type.main
      when 'int'
        for k,v of @hash
          if parseInt(k).toString() == k and !isFinite k
            throw new Error "Switch validation error. key '#{k}' can't be int"
      when 'float'
        for k,v of @hash
          if !isFinite k
            throw new Error "Switch validation error. key '#{k}' can't be float"
      when 'string'
        'nothing'
      else
        throw new Error "Switch validation error. Can't implement switch for condition type '#{@cond.type}'"
    
    for k,v of @hash
      v.validate(ctx)
    
    @f?.validate(ctx)
    
    return
  
class @Loop
  scope : null
  constructor:()->
    @scope = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    @scope.validate(ctx)
    return

class @While
  cond  : null
  scope : null
  constructor:()->
    @scope = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    if !@cond
      throw new Error "Loop validation error. cond missing"
    @cond.validate(ctx)
    @scope.validate(ctx)
    return

class @For_range

class @For_array

class @For_hash

class @Ret
  expr : null
  validate : (ctx = new module.Validation_context)->
    @expr?.validate(ctx)
    return
# ###################################################################################################
#    Exceptions
# ###################################################################################################
class @Try
  t : null
  c : null
  exception_var_name : ''
  
class @Throw
  t : null
# ###################################################################################################
#    decl
# ###################################################################################################
class @Var_decl
  name : null
  type : null
  validate : (ctx = new module.Validation_context)->
    type_validate @type

class @Class_decl

class @Fn_decl

class @Closure_decl

  
