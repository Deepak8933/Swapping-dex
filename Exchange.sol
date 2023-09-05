// SPDX-License-Identifier: MIT 
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


interface IFactory{
    function getExchange(address _tokenAddress) external returns(address);
}

interface IExchange {
    function ethToTokenSwap(uint256 _minTokens) external payable;

    function ethToTokenTransfer(uint256 _minTokens, address _recipient) external payable;
}
//exchange is inheriting ERC20
contract Exchange is ERC20 {
    address public tokenAddress;
    address public factoryAddress;
    constructor(address _token) ERC20("ETH TOKEN LP Token", "lpETHTOKEN"){
        require(_token != address(0), "Invalid token address");
        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    //getReserve returns the balance of 'token' held by this contract
    function getReserve() public view returns(uint256){
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    //addLiquidity allows users to add liquidity to the exchange
    function addLiquidity(uint256 _tokenAmt) public payable returns(uint256) {
        //if the reserve is empty, take any user value for initial liquidity
        if(getReserve() == 0){
            IERC20 token = IERC20(tokenAddress);
            //transfer the token from the user to the exchange
            token.transferFrom(msg.sender, address(this), _tokenAmt);
            uint256 liquidity = address(this).balance;
            //mint liquidity to the user
            _mint(msg.sender, liquidity);
            return liquidity;
        }
        else{
            //if the user is not empty, calculate the amt of lp tokens to be minted
            uint256 EthReserve = address(this).balance - msg.value;
            uint256 TokenReserve = getReserve();
            uint256 TokenAmt = (msg.value*TokenReserve)/EthReserve;
            require(_tokenAmt >= TokenAmt, "insufficient token amt");
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmt);
            uint256 liquidity = (totalSupply() * msg.value)/EthReserve;
            _mint(msg.sender, liquidity);
            return liquidity;
        }
        
    }

    //removeLiquidity allows users to remove liquidity from the exchange 
    function removeLiquidity(uint256 _amt) public returns(uint256, uint256){
        //check if the user wants to remove more than 0 LP tokens
        require(_amt>0, "Invalid amt");
        //calculating the amt of ETH and tokens to return to the user
        uint256 EthAmt = (address(this).balance * _amt)/totalSupply();
        uint256 TokenAmt = (getReserve() * _amt)/totalSupply();


        //burning the LP tokens from the user and transfering ETH and tokens to the user
        _burn(msg.sender, _amt);
        payable(msg.sender).transfer(EthAmt);
        IERC20(tokenAddress).transfer(msg.sender, TokenAmt);

        return (EthAmt, TokenAmt);
    }

    

    function getPrice(uint256 x, uint256 y) public pure returns(uint256) {
        require(x>0 && y>0, "Invalid reserves");
        return (x*1000)/y;
    }

    

    function getTokenAmt(uint _ethSold) public view returns(uint256) {
        require(_ethSold>0, "ethSold is too small");
        uint256 tokenReserve = getReserve();

        return getAmt(_ethSold, address(this).balance, tokenReserve);
    }
    function getEthAmt(uint _tokenSold) public view returns(uint256) {
        require(_tokenSold>0, "tokenSold is too small");
        uint256 tokenReserve = getReserve();

        return getAmt(_tokenSold, tokenReserve, address(this).balance);
    }

    //ethToToken fn allows users to swap ETH for tokens
    function ethToToken(uint256 _minTokens, address recipient) private {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmt(msg.value, address(this).balance - msg.value, tokenReserve);

        require(tokensBought >= _minTokens, "insufficient output tokens");

        IERC20(tokenAddress).transfer(recipient, tokensBought);
    }
    function ethToTokenTrasnfer(uint256 _minTokens, address _recipient) public payable{
        ethToToken(_minTokens, _recipient);
    }
    function EthToTokenSwap(uint256 _minTokens) public payable {
        ethToToken(_minTokens, msg.sender);
    }

    //TokenToEthSwap fn allows users to swap tokens for ETH
    function TokenToEthSwap(uint256 _tokenSold, uint256 _minEth) public{
        uint256 tokenReserve = getReserve();
        uint256 EthBought = getAmt(_tokenSold, tokenReserve, address(this).balance);

        require(EthBought >= _minEth, "insufficient output amt");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenSold);
        payable(msg.sender).transfer(EthBought);
    }

    function getAmt(
        uint256 inputAmt,
        uint256 x,
        uint256 y
    ) public pure returns(uint256) {
        require(x>0 && y>0, "invlid reserves");
        uint256 inputAmtWithFee = inputAmt * 99;
        uint256 numerator = inputAmtWithFee * y;
        uint256 denominator = (x*100) + inputAmtWithFee;
        return numerator/denominator;
    }

    function tokenToTokenSwap(uint256 _tokensSold, uint256 _minTokensBought, address _tokenAddress) public{
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        require(exchangeAddress != address(this) && exchangeAddress != address(0), "Invalid Exchange Address");

        

        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmt(_tokensSold, tokenReserve, address(this).balance);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(_minTokensBought, msg.sender);
    }
}