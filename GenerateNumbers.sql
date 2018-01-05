SELECT TOP (100000)
	 n = ROW_NUMBER() OVER (ORDER BY v.number) 
FROM [master]..spt_values v
JOIN [master]..spt_values vv ON vv.number = vv.number
ORDER BY
	 n