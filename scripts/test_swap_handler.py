from nile.nre import NileRuntimeEnvironment, Account

def u256(l, h=0):
    return (l, h)

def swaps(swap_list):
    encoded = []

    for swap in swap_list:
        encoded.extend([
            swap["token_in"],
            swap["token_out"],
            swap["rate"],
            swap["protocol"],
            swap["pool_address"]
        ])

    return encoded

def swap_params(token_in, token_out, amount, min_received, destination):
    return [
        token_in,
        token_out,
        *u256(amount),
        *u256(min_received),
        destination
    ]

def parse_units(amount, decimals):
    return int(amount * (10 ** decimals))

async def run(nre: NileRuntimeEnvironment):
    # get user account
    account: Account = await nre.get_or_deploy_account("MAINNET_DEPLOYER")

    pool_address = 0x04d0390b777b424e43839cd1e744799f3de6c176c7e32c1812a41dbd9c19db6a
    eth_address = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
    usdc_address = 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 

    max_fee = parse_units(0.001036985597507538, 18)
    amount = parse_units(0.001, 18)

    print("invoking with max_fee", max_fee, "and amount", amount)
    invoke_tx = await account.send(
        address_or_alias="mainnet_test",
        method="swap",
        calldata=[
            1,
            *swaps(swap_list=[
                { 
                    "token_in": eth_address,
                    "token_out": usdc_address,
                    "rate": 100,
                    "protocol": 2,
                    "pool_address": pool_address
                }
            ]),
            *swap_params(
                token_in=eth_address,
                token_out=usdc_address,
                amount=amount,
                min_received=0,
                destination=account.address
            )
        ],
        max_fee=max_fee
    )

    print(invoke_tx)
    print(dir(invoke_tx))

    # sim_tx = await invoke_tx.simulate()

    # print(sim_tx)