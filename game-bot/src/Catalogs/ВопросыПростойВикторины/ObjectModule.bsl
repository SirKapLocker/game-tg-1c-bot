
#Если Сервер Или ТолстыйКлиентОбычноеПриложение Или ВнешнееСоединение Тогда

#Область ОбработчикиСобытий

Процедура ОбработкаПроверкиЗаполнения(Отказ, ПроверяемыеРеквизиты)
	
	Фильтр = Новый Структура;
	Фильтр.Вставить("Верный", Истина);
	
	НайденныеСтроки = Ответы.НайтиСтроки(Фильтр);
	
	Если НайденныеСтроки.Количество() = 0 Тогда
		ОбщегоНазначения.СообщитьПользователю("Должен быть выбран верный ответ",,,, Отказ);
	КонецЕсли;
	
	Если НайденныеСтроки.Количество() > 1 Тогда
		ОбщегоНазначения.СообщитьПользователю("Должен быть только один верный ответ",,,, Отказ);
	КонецЕсли;

КонецПроцедуры

#КонецОбласти

#КонецЕсли