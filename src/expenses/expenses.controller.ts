import { Controller, Get, Post, Put, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { SessionUser } from '../approvals/approvals.service';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { ExpenseQueryDto } from './dto/expense-query.dto';
import { CreateExpenseCategoryDto } from './dto/create-expense-category.dto';

@ApiTags('expenses')
@ApiBearerAuth('JWT')
@UseGuards(JwtAuthGuard)
@Controller('expenses')
export class ExpensesController {
  constructor(private svc: ExpensesService) {}

  @Get('summary') @ApiOperation({ summary: 'Expense summary stats' })
  summary() { return this.svc.summary(); }

  @Post() @ApiOperation({ summary: 'Record an expense' })
  create(@Body() dto: CreateExpenseDto, @CurrentUser() user: SessionUser) {
    return this.svc.create(dto, user);
  }

  @Get() @ApiOperation({ summary: 'List expenses' })
  findAll(@Query() q: ExpenseQueryDto) { return this.svc.findAll(q); }

  @Get('categories') @ApiOperation({ summary: 'List expense categories' })
  findCategories() { return this.svc.findCategories(); }

  @Post('categories') @ApiOperation({ summary: 'Create an expense category' })
  createCategory(@Body() dto: CreateExpenseCategoryDto) { return this.svc.createCategory(dto); }

  @Get(':id') @ApiOperation({ summary: 'Get expense by ID' })
  findOne(@Param('id') id: string) { return this.svc.findOne(id); }

  @Put(':id') @ApiOperation({ summary: 'Update expense' })
  update(@Param('id') id: string, @Body() dto: UpdateExpenseDto) { return this.svc.update(id, dto); }
}
