# Revol
<br></br>

- To compile contracts (generate artifacts and ABI) run:
```
npm install
npx hardhat compile
```
 

# Deployment Doc

## Revol
### Parametros:
- initialOwner: Dueño del contrato, con permisos para modificar variables.
- treasureFee_: % que se destina al treasury en cada compra.
- daiAddress_: Token utilizado para comprar-vender revol.
- lpAddress_: Address del token LP usado en el staking en AAVE.
- aaveStakeAddress_: Contrato usado por aave para stakear tokens.

### Parámetros para Sepolia:
- initialOwner: Cualquier address. Sera el admin.
- treasureFee_: 25
- daiAddress_: 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357
- lpAddress_: 0x29598b72eb5CeBd806C5dCD549490FdA35B13cD8
- aaveStakeAddress_: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951

### Deployment and Setup Steps

- Deploy del Proxy.

- Deploy de la implementación.

- Aprobar DAI al contrato Revol.

- Llamar a la funcion InitPool, teniendo un balance de 100 DAI para que configure el rate inicial.


### Buy Steps

- Aprobar DAI al contrato Revol.

- Llamar a la funcion buyRevol pasando como parametro el amount y el receiver.


### Sell Steps

- Llamar a la funcion sellRevol pasando como parametro el amount.

<br></br>

## PFNfts
### Parametros:
- initialOwner: Dueño del contrato, con permisos para modificar variables.

- currency_: Moneda utilizada para comprar NFTs. Debe ser la misma que en el contrato de Revol (DAI).

- revolAddress_: Address del contrato de Revol.

- fee_: % de buyback para el user en revol en una compra de un NFT.

### Parámetros para Sepolia:
- initialOwner: Cualquier address. Sera el admin.
- currency_: 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357
- revolAddress_: Address del contrato de Revol en sepolia.
- fee_: 25


### Deployment and Setup Steps

- Deploy del Proxy.

- Deploy de la implementación.


### Métodos del Contrato

- Cualquiera puede llamar al metodo createCampaign para crear una nueva campaña, ingresando los parametros solicitados.

- Cualquier creador de una campaña puede modificar el URI de la campaña (url que apunta a la metadata) llamando al metodo setURI

- Cualquiera puede comprar un NFT de una coleccion simplemente llamando al metodo mint, pasando por parametro la cantidad de NFTs que se quieren mintear y el id de la campaña. NOTA: Para poder comprar un NFT, el comprador anteriormente debe aprobar al contrato de PFNfts en el contrato del currency para gastar el monto total de la compra.

- Cualquiera que posea NFTs de cierta campaña puede quemarlos (activarlos), lo cual equivaldría a intercambiarlos por bienes reales (chequeo para el vendedor para saber que alguien compro y quemo un NFT de su negocio). Para ello se llama a la funcion usePFNft pasando el id de la campaña y la cantidad de NFTs a quemar. Previamente el usuario debe aprobar al mismo contrato a controlar sus NFTs.

<br></br>

## PFNfts
### Parametros:
- _token: Contract address del token implementado para los votos (Lover).

- initialOwner: Dueño del contrato, con permisos para modificar variables.

### Deployment and Setup Steps

- Activar optimizacion en el contrato (200 runs).

- Deploy del Proxy.

- Deploy de la implementación.


### Métodos del Contrato

- Cualquiera puede llamar al metodo proposeCompensation para crear una nueva votacion por compensacion, ingresando los parametros solicitados. Esta funcion nos devolverá el id de la votación.

- Los miembros de la DAO pueden efectuar sus votos en las propuestas de compensaciones mediante el método castContributionVote, el cual es especifico para este tipo de votaciones, ingresando los parametros requeridos.

- Una vez finalizada la votacion, cualquiera puede ejecutar el metodo executeCompensation, que distribuira los tokens de la compensacion segun los resultados de la votacion.

<br></br>

## Lover
- Este contrato simplemente se le hace deploy y esta preparado para ser usado en DAOs mediante el standard ERC20Votes. Al creador se le mintearan la totalidad de los tokens, y este será el encargado de distribuirlos según corresponda.
