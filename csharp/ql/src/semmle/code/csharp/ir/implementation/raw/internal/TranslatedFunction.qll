import csharp
import semmle.code.csharp.ir.implementation.raw.IR
private import semmle.code.csharp.ir.implementation.Opcode
private import semmle.code.csharp.ir.internal.IRUtilities
private import semmle.code.csharp.ir.implementation.internal.OperandTag
private import semmle.code.csharp.ir.internal.TempVariableTag
private import InstructionTag
private import TranslatedElement
private import TranslatedExpr
private import TranslatedInitialization
private import TranslatedStmt
private import semmle.code.csharp.ir.internal.IRCSharpLanguage as Language

/**
 * Gets the `TranslatedFunction` that represents function `callable`.
 */
TranslatedFunction getTranslatedFunction(Callable callable) { result.getAST() = callable }

/**
 * Represents the IR translation of a function. This is the root element for
 * all other elements associated with this function.
 */
class TranslatedFunction extends TranslatedElement, TTranslatedFunction {
  Callable callable;

  TranslatedFunction() { this = TTranslatedFunction(callable) }

  final override string toString() { result = callable.toString() }

  final override Language::AST getAST() { result = callable }

  /**
   * Gets the function being translated.
   */
  final override Callable getFunction() { result = callable }

  final override TranslatedElement getChild(int id) {
    id = -2 and result = this.getConstructorInitializer()
    or
    id = -1 and result = this.getBody()
    or
    result = this.getParameter(id)
  }

  final private TranslatedConstructorInitializer getConstructorInitializer() {
    exists(ConstructorInitializer ci |
      ci = callable.getAChild() and
      result = getTranslatedConstructorInitializer(ci)
    )
  }

  final private TranslatedStmt getBody() { result = getTranslatedStmt(callable.getBody()) }

  final private TranslatedParameter getParameter(int index) {
    result = getTranslatedParameter(callable.getParameter(index))
  }

  final override Instruction getFirstInstruction() {
    result = this.getInstruction(EnterFunctionTag())
  }

  final override Instruction getInstructionSuccessor(InstructionTag tag, EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      tag = EnterFunctionTag() and
      result = this.getInstruction(AliasedDefinitionTag())
      or
      tag = AliasedDefinitionTag() and
      result = this.getInstruction(UnmodeledDefinitionTag())
      or
      (
        tag = UnmodeledDefinitionTag() and
        if exists(getThisType())
        then result = this.getInstruction(InitializeThisTag())
        else
          if exists(getParameter(0))
          then result = this.getParameter(0).getFirstInstruction()
          else result = this.getBodyOrReturn()
      )
      or
      (
        tag = InitializeThisTag() and
        if exists(getParameter(0))
        then result = this.getParameter(0).getFirstInstruction()
        else
          if exists(getConstructorInitializer())
          then result = this.getConstructorInitializer().getFirstInstruction()
          else result = this.getBodyOrReturn()
      )
      or
      tag = ReturnValueAddressTag() and
      result = this.getInstruction(ReturnTag())
      or
      tag = ReturnTag() and
      result = this.getInstruction(UnmodeledUseTag())
      or
      tag = UnwindTag() and
      result = this.getInstruction(UnmodeledUseTag())
      or
      tag = UnmodeledUseTag() and
      result = this.getInstruction(ExitFunctionTag())
    )
  }

  final override Instruction getChildSuccessor(TranslatedElement child) {
    exists(int paramIndex |
      child = this.getParameter(paramIndex) and
      if exists(callable.getParameter(paramIndex + 1))
      then result = this.getParameter(paramIndex + 1).getFirstInstruction()
      else
        if exists(getConstructorInitializer())
        then result = this.getConstructorInitializer().getFirstInstruction()
        else result = this.getBodyOrReturn()
    )
    or
    child = this.getConstructorInitializer() and
    result = this.getBodyOrReturn()
    or
    child = this.getBody() and
    result = this.getReturnSuccessorInstruction()
  }

  private Instruction getBodyOrReturn() {
    if exists(this.getBody())
    then result = this.getBody().getFirstInstruction()
    else result = this.getReturnSuccessorInstruction()
  }

  final override predicate hasInstruction(
    Opcode opcode, InstructionTag tag, Type resultType, boolean isLValue
  ) {
    (
      tag = EnterFunctionTag() and
      opcode instanceof Opcode::EnterFunction and
      resultType instanceof VoidType and
      isLValue = false
      or
      tag = UnmodeledDefinitionTag() and
      opcode instanceof Opcode::UnmodeledDefinition and
      resultType instanceof Language::UnknownType and
      isLValue = false
      or
      tag = AliasedDefinitionTag() and
      opcode instanceof Opcode::AliasedDefinition and
      resultType instanceof Language::UnknownType and
      isLValue = false
      or
      tag = InitializeThisTag() and
      opcode instanceof Opcode::InitializeThis and
      resultType = getThisType() and
      isLValue = true
      or
      tag = ReturnValueAddressTag() and
      opcode instanceof Opcode::VariableAddress and
      resultType = this.getReturnType() and
      not resultType instanceof VoidType and
      isLValue = true
      or
      (
        tag = ReturnTag() and
        resultType instanceof VoidType and
        isLValue = false and
        if this.getReturnType() instanceof VoidType
        then opcode instanceof Opcode::ReturnVoid
        else opcode instanceof Opcode::ReturnValue
      )
      or
      tag = UnwindTag() and
      opcode instanceof Opcode::Unwind and
      resultType instanceof VoidType and
      isLValue = false and
      (
        // Only generate the `Unwind` instruction if there is any exception
        // handling present in the function (compiler generated or not).
        exists(TryStmt try | try.getEnclosingCallable() = callable) or
        exists(ThrowStmt throw | throw.getEnclosingCallable() = callable)
      )
      or
      tag = UnmodeledUseTag() and
      opcode instanceof Opcode::UnmodeledUse and
      resultType instanceof VoidType and
      isLValue = false
      or
      tag = ExitFunctionTag() and
      opcode instanceof Opcode::ExitFunction and
      resultType instanceof VoidType and
      isLValue = false
    )
  }

  final override Instruction getExceptionSuccessorInstruction() {
    result = this.getInstruction(UnwindTag())
  }

  final override Instruction getInstructionOperand(InstructionTag tag, OperandTag operandTag) {
    tag = UnmodeledUseTag() and
    operandTag instanceof UnmodeledUseOperandTag and
    result.getEnclosingFunction() = callable and
    result.hasMemoryResult()
    or
    tag = UnmodeledUseTag() and
    operandTag instanceof UnmodeledUseOperandTag and
    result = getUnmodeledDefinitionInstruction()
    or
    tag = ReturnTag() and
    not this.getReturnType() instanceof VoidType and
    (
      operandTag instanceof AddressOperandTag and
      result = this.getInstruction(ReturnValueAddressTag())
      or
      operandTag instanceof LoadOperandTag and
      result = getUnmodeledDefinitionInstruction()
    )
  }

  final override Type getInstructionOperandType(InstructionTag tag, TypedOperandTag operandTag) {
    tag = ReturnTag() and
    not this.getReturnType() instanceof VoidType and
    operandTag instanceof LoadOperandTag and
    result = this.getReturnType()
  }

  final override IRVariable getInstructionVariable(InstructionTag tag) {
    tag = ReturnValueAddressTag() and
    result = this.getReturnVariable()
  }

  final override predicate hasTempVariable(TempVariableTag tag, Type type) {
    tag = ReturnValueTempVar() and
    type = this.getReturnType() and
    not type instanceof VoidType
  }

  /**
   * Gets the instruction to which control should flow after a `return`
   * statement. In C#, this should be the instruction which generates `VariableAddress[#return]`.
   */
  final Instruction getReturnSuccessorInstruction() {
    if this.getReturnType() instanceof VoidType
    then result = this.getInstruction(ReturnTag())
    else result = this.getInstruction(ReturnValueAddressTag())
  }

  /**
   * Gets the variable that represents the return value of this function.
   */
  final IRReturnVariable getReturnVariable() {
    result = getIRTempVariable(callable, ReturnValueTempVar())
  }

  /**
   * Gets the single `UnmodeledDefinition` instruction for this function.
   */
  final Instruction getUnmodeledDefinitionInstruction() {
    result = this.getInstruction(UnmodeledDefinitionTag())
  }

  /**
   * Gets the single `InitializeThis` instruction for this function. Holds only
   * if the function is an instance member function, constructor, or destructor.
   */
  final Instruction getInitializeThisInstruction() {
    result = this.getInstruction(InitializeThisTag())
  }

  /**
   * Gets the type pointed to by the `this` pointer for this function (i.e. `*this`).
   * Holds only if the function is an instance member function, constructor, or destructor.
   */
  final Type getThisType() {
    // `callable` is a user declared member and it is not static
    callable instanceof Member and
    not callable.(Member).isStatic() and
    result = callable.getDeclaringType()
    or
    // `callable` is a compiler generated accessor
    callable instanceof Accessor and
    not callable.(Accessor).isStatic() and
    result = callable.getDeclaringType()
  }

  /**
   * Holds if this function defines or accesses variable `var` with type `type`. This includes all
   * parameters and local variables, plus any static fields that are directly accessed by the
   * function.
   */
  final predicate hasUserVariable(Variable var, Type type) {
    (
      var.(Member).isStatic() and
      exists(VariableAccess access |
        access.getTarget() = var and
        access.getEnclosingCallable() = callable
      )
      or
      var.(LocalScopeVariable).getCallable() = callable
    ) and
    type = getVariableType(var)
  }

  final private Type getReturnType() { result = callable.getReturnType() }
}

/**
 * Gets the `TranslatedParameter` that represents parameter `param`.
 */
TranslatedParameter getTranslatedParameter(Parameter param) { result.getAST() = param }

/**
 * Represents the IR translation of a function parameter, including the
 * initialization of that parameter with the incoming argument.
 */
class TranslatedParameter extends TranslatedElement, TTranslatedParameter {
  Parameter param;

  TranslatedParameter() { this = TTranslatedParameter(param) }

  final override string toString() { result = param.toString() }

  final override Language::AST getAST() { result = param }

  final override Callable getFunction() { result = param.getCallable() }

  final override Instruction getFirstInstruction() {
    result = this.getInstruction(InitializerVariableAddressTag())
  }

  final override TranslatedElement getChild(int id) { none() }

  final override Instruction getInstructionSuccessor(InstructionTag tag, EdgeKind kind) {
    kind instanceof GotoEdge and
    (
      tag = InitializerVariableAddressTag() and
      result = this.getInstruction(InitializerStoreTag())
      or
      tag = InitializerStoreTag() and
      result = this.getParent().getChildSuccessor(this)
    )
  }

  final override Instruction getChildSuccessor(TranslatedElement child) { none() }

  final override predicate hasInstruction(
    Opcode opcode, InstructionTag tag, Type resultType, boolean isLValue
  ) {
    tag = InitializerVariableAddressTag() and
    opcode instanceof Opcode::VariableAddress and
    resultType = getVariableType(param) and
    isLValue = true
    or
    tag = InitializerStoreTag() and
    opcode instanceof Opcode::InitializeParameter and
    resultType = getVariableType(param) and
    isLValue = false
  }

  final override IRVariable getInstructionVariable(InstructionTag tag) {
    (
      tag = InitializerStoreTag() or
      tag = InitializerVariableAddressTag()
    ) and
    result = getIRUserVariable(getFunction(), param)
  }

  final override Instruction getInstructionOperand(InstructionTag tag, OperandTag operandTag) {
    tag = InitializerStoreTag() and
    (
      operandTag instanceof AddressOperandTag and
      result = this.getInstruction(InitializerVariableAddressTag())
    )
  }
}
