;with BinaryToBase64 as
(
	SELECT
		 c.ControlDescription
		,l.LanguageGenId
		,p.PropertyValue
	FROM Control c
	JOIN ControlBinaryProperty p ON p.ControlGenId = c.ControlGenId
	JOIN ref_Language l ON l.LanguageGenId = p.LanguageGenId
	WHERE c.FormGenId = 1010
)

SELECT *
FROM BinaryToBase64
FOR XML RAW, BINARY BASE64