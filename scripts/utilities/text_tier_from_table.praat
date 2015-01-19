tbl = selected("Table")
tblname$ = selected$("Table")
tg = selected("TextGrid")
select tg
start_grid = Get start time
end_grid = Get end time

new_tg = Create TextGrid: start_grid, end_grid, "value", ""
Rename: tblname$

select tbl
nrows = Get number of rows
for i from 1 to nrows
	select tbl
	start_row = Get value: i, "start"
	end_row = Get value: i, "end"
	row_mid = start_row + (end_row - start_row) / 2
	value$ = Get value: i, "text"
	select new_tg
	nocheck Insert boundary: 1, start_row
	nocheck Insert boundary: 1, end_row
	new_int = Get interval at time: 1, row_mid
	Set interval text: 1, new_int, value$
endfor
