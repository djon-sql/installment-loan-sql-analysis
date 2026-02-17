CREATE TABLE installment_plan
(
    contract_number int NOT NULL,
    client_id int NOT NULL,
    phone_id int NOT NULL,
    color_id tinyint NOT NULL,
    merchant_id tinyint NOT NULL,
    price numeric(10,2) NULL,
    date_purch date NULL,
    qu_inst int NOT NULL,
    inst int NULL,
    CONSTRAINT PK_installment_plan PRIMARY KEY (merchant_id, contract_number)
);

CREATE TABLE payments
(
    merchant_id tinyint NOT NULL,
    contract_number int NOT NULL,
    date_payment date NULL,
    payment int NULL,
    id INT IDENTITY(1,1) PRIMARY KEY,
    CONSTRAINT FK_payments_installment 
        FOREIGN KEY (merchant_id, contract_number)
        REFERENCES installment_plan(merchant_id, contract_number)
);
