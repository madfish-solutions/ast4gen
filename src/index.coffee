require 'fy'
module = @

type_validate = (t, ctx)->
  if !t
    throw new Error "Type validation error. type is missing"
  switch t.main
    when 'void', 'int', 'float', 'string', 'bool'
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
        throw new Error "Type validation error. #{t.main} can't have field_hash"
    when 'struct'
      if t.nest_list.length != 0
        throw new Error "Type validation error. #{t.main} must have nest_list 0"
      if 0 == h_count t.field_hash
        throw new Error "Type validation error. #{t.main} must have field_hash"
    when 'function'
      if t.nest_list.length == 0
        throw new Error "Type validation error. #{t.main} must have at least nest_list 1 (ret type)"
      if 0 != h_count t.field_hash
        throw new Error "Type validation error. #{t.main} can't have field_hash"
      ''
      # TODO defined types ...
    else
      if !ctx.check_type t.main
        throw new Error "unknown type '#{t}'"
  for v,k in t.nest_list
    # continue if k == 0 and t.main == 'function' and v.main == 'void' # it's ok
    type_validate v, ctx
  
  for k,v of t.field_hash
    type_validate v, ctx
  
  return

class @Validation_context
  parent    : null
  executable: false
  breakable : false
  returnable: false
  type_hash : {}
  var_hash  : {}
  this_type_name : null
  constructor:()->
    @type_hash = {}
    @var_hash  = {}
  
  seek_non_executable_parent : ()->
    if @executable
      @parent.seek_non_executable_parent()
    else
      @
  
  mk_nest : (pass_breakable)->
    ret = new module.Validation_context
    ret.parent = @
    ret.this_type_name = @this_type_name
    ret.returnable= @returnable
    ret.executable= @executable
    ret.breakable = @breakable if pass_breakable
    ret
  
  check_type : (id)->
    return found if found = @type_hash[id]
    if @parent
      return @parent.check_type id
    return null
  
  
  check_id : (id)->
    return found if found = @var_hash[id]
    if @parent
      return @parent.check_id id
    return null
  
  check_id_decl : (id)->
    @var_hash[id]
  

# ###################################################################################################
#    expr
# ###################################################################################################
# TODO array init
# TODO hash init
# TODO interpolated string init
class @This
  type : null
  validate : (ctx = new module.Validation_context)->
    type_validate @type, ctx
    if !ctx.this_type_name
      throw new Error "This validation error. Can't find this_type_name"
    return

class @Const
  val  : ''
  type : null
  validate : (ctx = new module.Validation_context)->
    type_validate @type, ctx
    switch @type.main
      when 'bool'
        unless @val in ['true', 'false']
          throw new Error "Const validation error. '#{@val}' can't be bool"
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
    type_validate @type, ctx
    if @type.main != 'array'
      throw new Error "Array_init validation error. type must be array but '#{@type}' found"
    
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
    type_validate @type, ctx
    if @type.main != 'hash'
      throw new Error "Hash_init validation error. type must be hash but '#{@type}' found"
    
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
    type_validate @type, ctx
    if @type.main != 'struct'
      throw new Error "Struct_init validation error. type must be struct but '#{@type}' found"
      
    for k,v of @hash
      v.validate(ctx)
      if !v.type.cmp cmp_type = @type.field_hash[k]
        throw new Error "Struct_init validation error. key '#{k}' must be type '#{cmp_type}' but '#{v.type}' found"
    
    return

class @Var
  name : ''
  type : null
  validate : (ctx = new module.Validation_context)->
    if !/^[_a-z][_a-z0-9]*$/i.test @name
      throw new Error "Var validation error. invalid identifier '#{@name}'"
    type_validate @type, ctx
    
    var_decl = ctx.check_id(@name)
    if !var_decl
      throw new Error "Var validation error. Id '#{id}' not defined"
    {type} = var_decl
    if !@type.cmp type
      throw new Error "Var validation error. Var type !+ Var_decl type '#{@type}' != #{type}"
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
  
  EQ : true
  NE : true
  GT : true
  LT : true
  GTE: true
  LTE: true
  
  INDEX_ACCESS : true # a[b] как бинарный оператор

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

@bin_op_ret_type_hash_list =
  ADD : [
    ['int', 'int', 'int']
    ['int', 'float', 'float']
    ['float', 'int', 'float']
    ['float', 'float', 'float']
    ['string', 'string', 'string']
  ]
  
  ASSIGN : [
    ['int', 'int', 'int']
    ['bool', 'bool', 'bool']
    ['float', 'float', 'float']
    ['string', 'string', 'string']
  ]

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
    
    type_validate @type, ctx
    
    if !module.allowed_bin_op_hash[@op]
      throw new Error "Bin_op validation error. Invalid op '#{@op}'"
    
    list = module.bin_op_ret_type_hash_list[@op]
    found = false
    for v in list
      continue if v[0] != @a.type.toString()
      continue if v[1] != @b.type.toString()
      found = true
      if v[2] != @type.toString()
        throw new Error "Bin_op validation error. bin_op=#{@op} with types #{@a.type} #{@b.type} should produce type #{v[2]} but #{@type} found"
      break
    if !found
      throw new Error "Bin_op validation error. Can't apply bin_op=#{@op} to #{@a.type} #{@b.type}"
    
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

@un_op_ret_type_hash_list =
  MINUS : [
    ['int', 'int']
    ['float', 'float']
  ]
class @Un_op
  a   : null
  op  : null
  type: null
  validate : (ctx = new module.Validation_context)->
    if !@a
      throw new Error "Un_op validation error. a missing"
    @a.validate(ctx)
    
    type_validate @type, ctx
    
    if !module.allowed_un_op_hash[@op]
      throw new Error "Un_op validation error. Invalid op '#{@op}'"
    
    list = module.un_op_ret_type_hash_list[@op]
    found = false
    for v in list
      continue if v[0] != @a.type.toString()
      found = true
      if v[1] != @type.toString()
        throw new Error "Un_op validation error. un_op=#{@op} with type #{@a.type} should produce type #{v[1]} but #{@type} found"
      break
    if !found
      throw new Error "Un_op validation error. Can't apply un_op=#{@op} to #{@a.type}"
    
    return

class @Field_access
  t : null
  name : ''
  type : null
  
  validate : (ctx = new module.Validation_context)->
    if !@t
      throw new Error "Field_access validation error. Missing target"
    
    if !@name
      throw new Error "Field_access validation error. Missing name"
    
    type_validate @type
    
    if !nest_type = @t.type.field_hash[@name]
      throw new Error "Field_access validation error. Access to missing field '#{@name}'"
    
    if !@type.cmp nest_type
      throw new Error "Field_access validation error. Access to field '#{@name}' with type '#{nest_type}' but result '#{@type}'"
    
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
    
    type_validate @type, ctx
    if !@type.cmp @fn.type.nest_list[0]
      throw new Error "Fn_call validation error. Return type and function decl return type doesn't match #{@fn.type.nest_list[0]} != #{@type}"
    
    if @fn.type.nest_list.length-1 != @arg_list.length
      throw new Error "Fn_call validation error. Expected arg count=#{@fn.type.nest_list.length-1} found=#{@arg_list.length}"
    
    for arg,k in @arg_list
      arg.validate(ctx)
      if !@fn.type.nest_list[k+1].cmp arg.type
        throw new Error "Fn_call validation error. arg[#{k}] type mismatch. Expected=#{@fn.type.nest_list[k+1]} found=#{arg.type}"
    return

# ###################################################################################################
#    stmt
# ###################################################################################################
# TODO var_decl check
class @Scope
  list : []
  constructor:()->
    @list = []
  
  validate : (ctx = new module.Validation_context)->
    ctx_nest = ctx.mk_nest(true)
    
    for stmt in @list # for Class_decl
      stmt.register?(ctx_nest)
    
    for stmt in @list
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
    
    unless @cond.type.main in ['bool', 'int']
      throw new Error "If validation error. cond must be bool or int"
    
    @cond.validate(ctx)
    @t.validate(ctx)
    @f.validate(ctx)
    
    if @t.list.length == 0
      perr "Warning. If empty true body"
    
    if @t.list.length == 0 and @f.list.length == 0
      throw new Error "If validation error. Empty true and false sections"
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
          if parseInt(k).toString() != k or !isFinite k
            throw new Error "Switch validation error. key '#{k}' can't be int"
      # when 'float' # не разрешаем switch по  float т.к. нельзя сравнивать float'ы через ==
        # for k,v of @hash
          # if !isFinite k
            # throw new Error "Switch validation error. key '#{k}' can't be float"
      when 'string'
        'nothing'
      else
        throw new Error "Switch validation error. Can't implement switch for condition type '#{@cond.type}'"
    
    for k,v of @hash
      v.validate(ctx.mk_nest())
    
    @f?.validate(ctx)
    
    return
  
class @Loop
  scope : null
  constructor:()->
    @scope = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    ctx_nest = ctx.mk_nest()
    ctx_nest.breakable = true
    @scope.validate(ctx_nest)
    
    found = false
    walk = (t)->
      switch t.constructor.name
        when 'Scope'
          for v in t.list
            walk v
        when 'If'
          walk t.t
          walk t.f
        when 'Break', 'Ret'
          found = true
    
    walk @scope
    if !found
      throw new Error "Loop validation error. Break or Ret not found"
    # Не нужен т.к. все-равно ищем break
    # if @scope.list.length == 0
      # throw new Error "Loop validation error. Loop while is not allowed"
    return
  
class @Break
  constructor:()->
  
  validate : (ctx = new module.Validation_context)->
    if !ctx.breakable
      throw new Error "Break validation error. You can't use break outside loop, while"
    
    return

class @Continue
  constructor:()->
  
  validate : (ctx = new module.Validation_context)->
    if !ctx.breakable
      throw new Error "Continue validation error. You can't use continue outside loop, while"
    
    return

class @While
  cond  : null
  scope : null
  constructor:()->
    @scope = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    if !@cond
      throw new Error "While validation error. cond missing"
    
    unless @cond.type.main in ['bool', 'int']
      throw new Error "While validation error. cond must be bool or int"
    
    @cond.validate(ctx)
    @scope.validate(ctx)
    
    if @scope.list.length == 0
      throw new Error "While validation error. Empty while is not allowed"
    return

class @For_range
  exclusive : true
  i     : null
  a     : null
  b     : null
  step  : null
  scope : null
  constructor:()->
    @scope = new module.Scope

class @For_array
  k : null
  v : null
  t : null
  scope : null
  constructor:()->
    @scope = new module.Scope

class @For_hash
  k : null
  v : null
  t : null
  scope : null
  constructor:()->
    @scope = new module.Scope

class @Ret
  t : null
  validate : (ctx = new module.Validation_context)->
    @t?.validate(ctx)
    if !ctx.returnable
      throw new Error "Ret validation error. ctx must be returnable"
    
    return
# ###################################################################################################
#    Exceptions
# ###################################################################################################
class @Try
  t : null
  c : null
  exception_var_name : ''
  constructor : ()->
    @t = new module.Scope
    @c = new module.Scope
  
class @Throw
  t : null
# ###################################################################################################
#    decl
# ###################################################################################################
class @Var_decl
  name : ''
  type : null
  validate : (ctx = new module.Validation_context)->
    type_validate @type, ctx
    if ctx.check_id_decl(@name)
      throw new Error "Var_decl validation error. Redeclare '#{@name}'"
    
    ctx.var_hash[@name] = @
    return

class @Class_decl
  name  : ''
  scope : null
  constructor:()->
    @scope = new module.Scope
  
  register : (ctx = new module.Validation_context)->
    if ctx.check_type @name
      throw new Error "Already registered '#{@name}'"
    ctx.type_hash[@name] = @
    return
  
  validate : (ctx = new module.Validation_context)->
    if !@name
      throw new Error "Class_decl validation error. Class should have name"
    
    for v in @scope.list
      unless v.constructor.name in ['Var_decl', 'Fn_decl']
        throw new Error "Class_decl validation error. Only Var_decl and Fn_decl allowed at Class_decl, but '#{v.constructor.name}' found"
    
    ctx_nest = ctx.mk_nest()
    ctx_nest.this_type_name = @name
    @scope.validate(ctx_nest)
    return

class @Fn_decl
  is_closure : false
  name : ''
  type : null
  arg_name_list : []
  scope : null
  constructor:()->
    @arg_name_list = []
    @scope = new module.Scope
  
  validate : (ctx = new module.Validation_context)->
    if !@name and !@is_closure
      throw new Error "Fn_decl validation error. Function should have name"
    
    type_validate @type, ctx
    if @type.main != 'function'
      throw new Error "Fn_decl validation error. Type must be function but '#{@type}' found"
    if @type.nest_list.length-1 != @arg_name_list.length
      throw new Error "Fn_decl validation error. @type.nest_list.length-1 != @arg_name_list #{@type.nest_list.length-1} != #{@arg_name_list.length}"
    
    if @is_closure
      ctx_nest = ctx.mk_nest()
    else
      ctx_nest = ctx.seek_non_executable_parent().mk_nest()
    ctx_nest.executable = true
    ctx_nest.returnable = true
    
    for name,k in @arg_name_list
      decl = new module.Var_decl
      decl.name = name
      decl.type = @type.nest_list[1+k]
      ctx_nest.var_hash[name] = decl
    
    @scope.validate(ctx_nest)
    return
  
