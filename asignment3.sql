-- Функція 

create or replace function calculate_order_total(p_order_id int)
RETURNS numeric AS $$
    SELECT COALESCE(SUM(quantity * price), 0)
    FROM order_items
    WHERE order_id = p_order_id;
$$ LANGUAGE sql;

-- Процедур 1

create or replace procedure create_order(p_customer_id int)
language plpgsql as $$
begin
	if exists (
		select 1
		from customers
		where customer_id = p_customer_id) then
		insert into orders (customer_id, order_date, total_amount)
		values (p_customer_id, CURRENT_TIMESTAMP, 0);
	end if;
end;
$$;

-- Процедур 2

create or replace procedure add_product_to_order(
	p_order_id int,
	p_product_id int,
	p_quantity int
)
language plpgsql AS $$
begin
    with updated_product AS (
        update products
        set stock_quantity = stock_quantity - p_quantity
        where product_id = p_product_id
          and p_quantity > 0
          and stock_quantity >= p_quantity
        returning price
    )
    insert into order_items (order_id, product_id, quantity, price)
    select 
		p_order_id, 
		p_product_id, 
		p_quantity, price
    from updated_product;
end;
$$;

-- Тригер 1

create or replace function trg_func()
returns trigger as $$
begin
	update orders
	set total_amount = calculate_order_total(COALESCE(new.order_id, old.order_id))
	where order_id = COALESCE(new.order_id, old.order_id);

	if TG_OP = 'DELETE' then
		return old;
	else 
		return new;
	end if;
end;
$$ language plpgsql;

create trigger trg
after insert or update or dedelete on order_items
for each row
execute function trg_func();

-- Тригер 2

create or replace function trg2_func()
returns trigger as $$
begin
	insert into order_log (order_id, customer_id, action)
	values (new.order_id, new.customer_id, 'Order Created');
	return new;
end;
$$ language plpgsql;

create trigger trg2
after insert on orders
for each row
execute function trg2_func();

-- Тести
select * 
from products
where product_id = 1;

call create_order(1);

select *
from orders 

select *
from order_log

call add_product_to_order(4, 1, 2);

select *
from orders 
where order_id = 4;

select * 
from products
where product_id = 1;
