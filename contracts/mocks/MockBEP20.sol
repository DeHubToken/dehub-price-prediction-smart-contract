import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";

contract MockBEP20 is BEP20 {
    event Minted(address receiver, uint tokenAmt);
    
    constructor() public BEP20("Mock Token", "MOC") {
        _mint(msg.sender, 30000000000 * 10 ** 18);
    }

    function mint(address receiver, uint256 tokenAmt) public {
        _mint(receiver, tokenAmt);
        emit Minted(receiver, tokenAmt);
    }
}