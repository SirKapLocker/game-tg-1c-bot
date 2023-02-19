
#Область ПрограммныйИнтерфейс

Процедура ОбработкаВходящихВФоне(АдресХранилища) Экспорт
	
	ВремяНачалаОбработки = ТекущаяДатаСеанса();
	
	РезультатПолученияОбновления = ПолучитьОбновления();
	РезультатОбработкиОчереди = ОбработатьОчередьСообщений();
	
	ВремяОкончанияОбработки = ТекущаяДатаСеанса();
	
	ШаблонЛога = "Итерация обработки на сервере %1 - %2: Сообщений получено %3, Ошибок обработки %4";
	
	ЗаписьЛога = СтрШаблон(ШаблонЛога,
		Формат(ВремяНачалаОбработки, "ДЛФ=T;"),
		Формат(ВремяОкончанияОбработки, "ДЛФ=T;"),
		РезультатПолученияОбновления.СообщенияОчереди.Количество(),
		РезультатОбработкиОчереди.КоличествоОшибок);
		
	ПоместитьВоВременноеХранилище(ЗаписьЛога, АдресХранилища)
	
КонецПроцедуры

Функция ОбработатьОчередьСообщений() Экспорт
	
	Результат = Новый Структура;
	Результат.Вставить("КоличествоОшибок", 0);
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	ОчередьОбработкиСообщений.Ссылка
		|ИЗ
		|	Справочник.ОчередьОбработкиСообщений КАК ОчередьОбработкиСообщений
		|ГДЕ
		|	НЕ ОчередьОбработкиСообщений.ОшибкаОбработки";
	
	Выборка = Запрос.Выполнить().Выбрать();
	
	Пока Выборка.Следующий() Цикл
		
		Попытка
			ЗаблокироватьДанныеДляРедактирования(Выборка.Ссылка);
		Исключение
			Продолжить;
		КонецПопытки;
		
		ЭлементОчередиОбъект = Выборка.Ссылка.ПолучитьОбъект();
		ЭлементОчередиОбъект.ОбменДанными.Загрузка = Истина;
				
		Попытка
			ОбработатьЭлементОчереди(ЭлементОчередиОбъект);
			ЭлементОчередиОбъект.Удалить();
		Исключение
			ЭлементОчередиОбъект.ТекстОшибки = ОбработкаОшибок.ПодробноеПредставлениеОшибки(ИнформацияОбОшибке());
			ЭлементОчередиОбъект.КоличествоПопыток = ЭлементОчередиОбъект.КоличествоПопыток + 1;
			Если ЭлементОчередиОбъект.КоличествоПопыток >= 3 Тогда
				ЭлементОчередиОбъект.ОшибкаОбработки = Истина;
			КонецЕсли;
			ЭлементОчередиОбъект.Записать();
			Результат.КоличествоОшибок = Результат.КоличествоОшибок + 1;
		КонецПопытки;
					
		РазблокироватьДанныеДляРедактирования(Выборка.Ссылка);
		
	КонецЦикла;
	
	Возврат Результат;
	
КонецФункции

Функция ПолучитьОбновления() Экспорт
	
	Результат = Новый Структура;
	
	Метод = ИнтеграцияТелеграмСлужебный.МетодПолучитьОбновления();
	ОписаниеЗапроса = ИнтеграцияТелеграмСлужебный.ОписаниеЗапросаТелеграм(Метод);
	
	ИдентификаторПоследнегоОбновления = Константы.ИдентификаторПоследнегоОбновления.Получить();
	
	ОписаниеЗапроса.Параметры.Вставить("timeout", 60);
	ОписаниеЗапроса.Параметры.Вставить("offset", ИдентификаторПоследнегоОбновления + 1);
	
	Ответ = ИнтеграцияТелеграмСлужебный.ВыполнитьЗапросТелеграм(ОписаниеЗапроса);
	
	ТекстОтвета = Ответ.ПолучитьТелоКакСтроку();
	
	ОписаниеОбновлений = СериализацияДанных.СтрокуJSONВОбъект(ТекстОтвета);
	
	СообщенияОчереди = Новый Массив;
	
	Для Каждого Обновление Из ОписаниеОбновлений.result Цикл
		
		ИдентификаторПоследнегоОбновления = Обновление.update_id;
		
		СохраненноеВходящееСообщение = ПолучитьСохраненноеВходящееСообщение(Обновление.update_id);		
		СохраненноеВходящееСообщение.Данные = СериализацияДанных.ОбъектВСтрокуJSON(Обновление);
		
		Если Обновление.Свойство("message") Тогда
			
			Сообщение = Обновление.message;
			
			Если Сообщение.Свойство("from") Тогда
				СохраненноеВходящееСообщение.Отправитель = ПолучитьОтправителя(Сообщение.from);
			КонецЕсли;
			
			Если Сообщение.Свойство("chat") Тогда				
				СохраненноеВходящееСообщение.Чат = ПолучитьЧат(Сообщение.chat);
			КонецЕсли;
			
		КонецЕсли;
		
		СохраненноеВходящееСообщение.Записать();
		
		СообщенияОчереди.Добавить(СохраненноеВходящееСообщение.Ссылка);		
		
	КонецЦикла;
	
	Константы.ИдентификаторПоследнегоОбновления.Установить(ИдентификаторПоследнегоОбновления);
	
	Результат.Вставить("Текст", ТекстОтвета);
	Результат.Вставить("СообщенияОчереди", СообщенияОчереди);
	
	Возврат Результат;

КонецФункции

Процедура ОтправитьСообщение(Получатель, Текст, Знач ДополнительныеСвойства = Неопределено) Экспорт
	
	Если ДополнительныеСвойства = Неопределено Тогда
		ДополнительныеСвойства = ДополнительныеСвойстваИсходящегоСообщения()
	КонецЕсли;
	
	Метод = ИнтеграцияТелеграмСлужебный.МетодОтправитьСообщение();
	ОписаниеЗапроса = ИнтеграцияТелеграмСлужебный.ОписаниеЗапросаТелеграм(Метод);
	
	ДанныеОтвета = Новый Структура;
	ДанныеОтвета.Вставить("chat_id", Получатель);
	ДанныеОтвета.Вставить("parse_mode", ДополнительныеСвойства.ТипТекста);
	ДанныеОтвета.Вставить("text", Текст);
	
	Если ДополнительныеСвойства.Клавиатура <> Неопределено Тогда
		ДанныеОтвета.Вставить("reply_markup", ДополнительныеСвойства.Клавиатура);
	КонецЕсли;		
	
	ОписаниеЗапроса.Тело = СериализацияДанных.ОбъектВСтрокуJSON(ДанныеОтвета);
	ОписаниеЗапроса.ТипТела = ТипТелаJSON();
	
	ИнтеграцияТелеграмСлужебный.ВыполнитьЗапросТелеграм(ОписаниеЗапроса);
	
КонецПроцедуры

Процедура ОтправитьКартинку(Получатель, ДанныеКартинки, Текст = "", Знач ДополнительныеСвойства = Неопределено) Экспорт
	
	Если ДополнительныеСвойства = Неопределено Тогда
		ДополнительныеСвойства = ДополнительныеСвойстваИсходящегоСообщения()
	КонецЕсли;
	
	Метод = ИнтеграцияТелеграмСлужебный.МетодОтправитьКартинку();
	ОписаниеЗапроса = ИнтеграцияТелеграмСлужебный.ОписаниеЗапросаТелеграм(Метод);
	
	Разделитель = Строка(Новый УникальныйИдентификатор());
	
	ОписаниеЗапроса.Тело = СоставноеТелоОтправкаКартинки(Разделитель, Получатель, 
		ДанныеКартинки, Текст, ДополнительныеСвойства.Клавиатура);
	ОписаниеЗапроса.ТипТела = ТипТелаMultipart(Разделитель);
	
	ИнтеграцияТелеграмСлужебный.ВыполнитьЗапросТелеграм(ОписаниеЗапроса);
	
КонецПроцедуры

Процедура РедактироватьСообщение(ИдентификаторЧата, ИдентификаторСообщения, Текст, 
	Знач ДополнительныеСвойства = Неопределено) Экспорт
	
	Если ДополнительныеСвойства = Неопределено Тогда
		ДополнительныеСвойства = ДополнительныеСвойстваИсходящегоСообщения()
	КонецЕсли;
	
	Метод = ИнтеграцияТелеграмСлужебный.МетодРедактироватьСообщение();
	ОписаниеЗапроса = ИнтеграцияТелеграмСлужебный.ОписаниеЗапросаТелеграм(Метод);
	
	ДанныеОтвета = Новый Структура;
	ДанныеОтвета.Вставить("chat_id", ИдентификаторЧата);
	ДанныеОтвета.Вставить("message_id", ИдентификаторСообщения);
	ДанныеОтвета.Вставить("parse_mode", ДополнительныеСвойства.ТипТекста);
	ДанныеОтвета.Вставить("text", Текст);
	
	Если ДополнительныеСвойства.Клавиатура <> Неопределено Тогда
		ДанныеОтвета.Вставить("reply_markup", ДополнительныеСвойства.Клавиатура);
	КонецЕсли;		
	
	ОписаниеЗапроса.Тело = СериализацияДанных.ОбъектВСтрокуJSON(ДанныеОтвета);
	ОписаниеЗапроса.ТипТела = ТипТелаJSON();
	
	ИнтеграцияТелеграмСлужебный.ВыполнитьЗапросТелеграм(ОписаниеЗапроса);
	
КонецПроцедуры

Процедура РедактироватьПодпись(ИдентификаторЧата, ИдентификаторСообщения, Текст, 
	Знач ДополнительныеСвойства = Неопределено) Экспорт
	
	Если ДополнительныеСвойства = Неопределено Тогда
		ДополнительныеСвойства = ДополнительныеСвойстваИсходящегоСообщения()
	КонецЕсли;
	
	Метод = ИнтеграцияТелеграмСлужебный.МетодРедактироватьПодпись();
	ОписаниеЗапроса = ИнтеграцияТелеграмСлужебный.ОписаниеЗапросаТелеграм(Метод);
	
	ДанныеОтвета = Новый Структура;
	ДанныеОтвета.Вставить("chat_id", ИдентификаторЧата);
	ДанныеОтвета.Вставить("message_id", ИдентификаторСообщения);
	ДанныеОтвета.Вставить("parse_mode", ДополнительныеСвойства.ТипТекста);
	ДанныеОтвета.Вставить("caption", Текст);
	
	Если ДополнительныеСвойства.Клавиатура <> Неопределено Тогда
		ДанныеОтвета.Вставить("reply_markup", ДополнительныеСвойства.Клавиатура);
	КонецЕсли;		
	
	ОписаниеЗапроса.Тело = СериализацияДанных.ОбъектВСтрокуJSON(ДанныеОтвета);
	ОписаниеЗапроса.ТипТела = ТипТелаJSON();
	
	ИнтеграцияТелеграмСлужебный.ВыполнитьЗапросТелеграм(ОписаниеЗапроса);
	
КонецПроцедуры

Функция ДополнительныеСвойстваИсходящегоСообщения() Экспорт
	
	Результат = Новый Структура;
	Результат.Вставить("ТипТекста", "HTML");
	Результат.Вставить("Клавиатура");

	Возврат Результат;
	
КонецФункции

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

// Получить сохраненное входящее сообщение.
// 
// Параметры:
//  Код - Число
// 
// Возвращаемое значение:
//  СправочникОбъект.ОчередьОбработкиСообщений - Получить сохраненное входящее сообщение
Функция ПолучитьСохраненноеВходящееСообщение(Код)
	
	Сообщение = Справочники.ОчередьОбработкиСообщений.НайтиПоКоду(Код);
	
	Если Не Сообщение.Пустая() Тогда
		Возврат Сообщение.ПолучитьОбъект();
	КонецЕсли;
	
	СообщениеОбъект = Справочники.ОчередьОбработкиСообщений.СоздатьЭлемент();
	СообщениеОбъект.Код = Код;
	
	Возврат СообщениеОбъект	
	
КонецФункции

// Получить отправителя.
// 
// Параметры:
//  ОписаниеОтправителя  - Структура
// 
// Возвращаемое значение:
//  СправочникСсылка.УчетныеЗаписиТелеграм - Сохраненный отправитель
Функция ПолучитьОтправителя(ОписаниеОтправителя)
	
	Отправитель = Справочники.УчетныеЗаписиТелеграм.НайтиПоКоду(ОписаниеОтправителя.id);
	
	Если Не Отправитель.Пустая() Тогда
		Возврат Отправитель;
	КонецЕсли;
	
	ОтправительОбъект = Справочники.УчетныеЗаписиТелеграм.СоздатьЭлемент();
	ОтправительОбъект.Код = ОписаниеОтправителя.id;
	
	ЧастиНаименования = Новый Массив;
	
	Если ОписаниеОтправителя.Свойство("first_name") Тогда
		ЧастиНаименования.Добавить(ОписаниеОтправителя.first_name);
	КонецЕсли;

	Если ОписаниеОтправителя.Свойство("last_name") Тогда
		ЧастиНаименования.Добавить(ОписаниеОтправителя.last_name);
	КонецЕсли;

	Если ОписаниеОтправителя.Свойство("username") Тогда
		ЧастиНаименования.Добавить("(" + ОписаниеОтправителя.username + ")");
	КонецЕсли;
	
	ОтправительОбъект.Наименование = СтрСоединить(ЧастиНаименования, " ");
	
	ОтправительОбъект.Записать();
	
	Возврат ОтправительОбъект.Ссылка;
	
КонецФункции

// Получить чат.
// 
// Параметры:
//  ОписаниеЧата  - Структура
// 
// Возвращаемое значение:
//  СправочникСсылка.ТелеграмЧаты - Сохраненный чат
Функция ПолучитьЧат(ОписаниеЧата)
	
	Чат = Справочники.ТелеграмЧаты.НайтиПоКоду(ОписаниеЧата.id);
	
	Если Не Чат.Пустая() Тогда
		Возврат Чат;
	КонецЕсли;
	
	ЧатОбъект = Справочники.ТелеграмЧаты.СоздатьЭлемент();
	ЧатОбъект.Код = ОписаниеЧата.id;
	
	ЧастиНаименования = Новый Массив;
	
	Если ОписаниеЧата.Свойство("title") Тогда
		ЧастиНаименования.Добавить(ОписаниеЧата.title);
	КонецЕсли;
	
	Если ОписаниеЧата.Свойство("first_name") Тогда
		ЧастиНаименования.Добавить(ОписаниеЧата.first_name);
	КонецЕсли;

	Если ОписаниеЧата.Свойство("last_name") Тогда
		ЧастиНаименования.Добавить(ОписаниеЧата.last_name);
	КонецЕсли;

	Если ОписаниеЧата.Свойство("username") Тогда
		ЧастиНаименования.Добавить("(" + ОписаниеЧата.username + ")");
	КонецЕсли;
	
	ЧатОбъект.Наименование = СтрСоединить(ЧастиНаименования, " ");
	
	ЧатОбъект.Записать();
	
	Возврат ЧатОбъект.Ссылка;
	
КонецФункции

Процедура ОбработатьЭлементОчереди(ЭлементОчередиОбъект)
	
	ДанныеЭлемента = СериализацияДанных.СтрокуJSONВОбъект(ЭлементОчередиОбъект.Данные);
	
	ИнтеграцияТелеграмПереопределяемый.ПриОбработкеЭлементаОчереди(ЭлементОчередиОбъект, ДанныеЭлемента);	
		
КонецПроцедуры

Функция СоставноеТелоОтправкаКартинки(Разделитель, Получатель, ДанныеКартинки, Текст, Клавиатура)
	
	Тело = Новый ПотокВПамяти();
	
	ЗаписьДанных = Новый ЗаписьДанных(Тело);
	
	ЗаписьДанных.ЗаписатьСтроку("--" + Разделитель);
	ЗаписьДанных.ЗаписатьСтроку("Content-disposition: form-data; name=""chat_id""");
	ЗаписьДанных.ЗаписатьСтроку("");
	ЗаписьДанных.ЗаписатьСтроку(XMLСтрока(Получатель));
	
	ЗаписьДанных.ЗаписатьСтроку("--" + Разделитель);
	ЗаписьДанных.ЗаписатьСтроку("Content-disposition: form-data; name=""photo""; filename=""image.jpg""");
	ЗаписьДанных.ЗаписатьСтроку("Content-Type: image/jpeg");
	ЗаписьДанных.ЗаписатьСтроку("");
	ЗаписьДанных.Записать(ДанныеКартинки);
	ЗаписьДанных.ЗаписатьСтроку("");
	
	Если ЗначениеЗаполнено(Текст) Тогда
		ЗаписьДанных.ЗаписатьСтроку("--" + Разделитель);
		ЗаписьДанных.ЗаписатьСтроку("Content-disposition: form-data; name=""caption""");
		ЗаписьДанных.ЗаписатьСтроку("");
		ЗаписьДанных.ЗаписатьСтроку(Текст);
		
		ЗаписьДанных.ЗаписатьСтроку("--" + Разделитель);
		ЗаписьДанных.ЗаписатьСтроку("Content-disposition: form-data; name=""parse_mode""");
		ЗаписьДанных.ЗаписатьСтроку("");
		ЗаписьДанных.ЗаписатьСтроку("HTML");
	КонецЕсли;
	
	Если Клавиатура <> Неопределено Тогда
		ЗаписьДанных.ЗаписатьСтроку("--" + Разделитель);
		ЗаписьДанных.ЗаписатьСтроку("Content-disposition: form-data; name=""reply_markup""");
		ЗаписьДанных.ЗаписатьСтроку("Content-Type: application/json");
		ЗаписьДанных.ЗаписатьСтроку("");
		ЗаписьДанных.ЗаписатьСтроку(СериализацияДанных.ОбъектВСтрокуJSON(Клавиатура));
	КонецЕсли;
		
	ЗаписьДанных.ЗаписатьСтроку("--" + Разделитель + "--");
		
	ЗаписьДанных.Закрыть();
	
	Возврат Тело.ЗакрытьИПолучитьДвоичныеДанные();
	
КонецФункции

Функция ТипТелаJSON()	
	Возврат "application/json";
КонецФункции

Функция ТипТелаMultipart(Разделитель)
	Шаблон = "multipart/form-data; boundary=%1"; 	
	Возврат СтрШаблон(Шаблон, Разделитель);
КонецФункции

#КонецОбласти

