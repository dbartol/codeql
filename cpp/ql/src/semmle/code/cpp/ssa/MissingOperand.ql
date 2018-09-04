/**
 * @name IR Sanity Check
 * @description Performs sanity checks on the Intermediate Representation. This query should have no results. 
 * @kind problem
 * @id cpp/ssa-ir-sanity-check
 */

import semmle.code.cpp.ssa.internal.ssa.IRImpl

from Instruction instr, OperandTag operand
where InstructionSanity::missingOperand(instr, operand)
select instr, "Instruction '" + instr.toString() + "' is missing an expected operand with tag '" + operand.toString() + "'."
